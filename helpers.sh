#!/bin/bash

_LOG_SOURCE=$0
_LOG_SOURCETYPE=
_LOG_TOKEN=
_LOG_TARGET_URI=
_LOG_INDEX=

if [ -n "$fqdn" ]; then
  _LOG_HOST=$fqdn
else
  _LOG_HOST=$(hostname)
fi

function httplog_get_epoch_time() {
  if [ -x "/usr/bin/perl" ]; then
    _httplog_epoch_time=$(perl -e 'print time(), "\n" ')
  elif [ -x "/usr/bin/nawk" ]; then
    _httplog_epoch_time=$(nawk 'BEGIN{print srand()}')
  else # try for gnu date
    _httplog_epoch_time=$(date +"%s")
  fi

  # validate
  if [ -z "$_httplog_epoch_time" ]; then
    _httplog_epoch_time=1  # woot! 1970, which we can at least catch
  elif [ "$_httplog_epoch_time" -eq "$_httplog_epoch_time" ]; then
    : # do nothing, but we can't negate the test and have it work -- test blows
    # up when it isn't an integer and doesn't trigger the else.  Ever.
  else
    _httplog_epoch_time=1 # woot! 1970, which we can at least catch
  fi
  echo $_httplog_epoch_time
}


function httplog_check() {
  if [ -z "$_LOG_TOKEN" ]; then
    echo "ERROR: don't have log token for HTTP logging" >&2
    return 1
  fi
  if [ -z "$_LOG_TARGET_URI" ]; then
    echo "ERROR: don't have log token for HTTP logging" >&2
    return 1
  fi
}

function httplog_set_token() {
  _LOG_TOKEN=$1
}

function httplog_set_sourcetype() {
  _LOG_SOURCETYPE=$1
}

function httplog_set_source() {
  _LOG_SOURCE=$1
}

function httplog_set_index() {
  _LOG_INDEX=$1
}

function httplog_set_target() {
  _LOG_TARGET_URI=$1
}

function httplog_set_host() {
  _LOG_HOST=$1
}

# if we're not configured, fall back to stderr which will go to splunkd.log/_internal
function httplog_fallback() {
  _message=$1
  shift
  _severity=$2
  shift
  # remaining parameters
  _other=$*

  echo "$0: $_severity: (httplog not configured): $message (additional params: $_other)" 1>&2
}

# param 1 is message, param 2 is severity, param 3+ is key=value to include
function httplog() {
  # get the message
  _message=$1
  shift
  if [ -z "$_message" ]; then
    _message="(none provided)"
  fi

  # get severity or default it
  if [ -n "$1" ]; then
    _severity=$1
    shift
  else
    _severity="INFO"
  fi

  _current_time=$(httplog_get_epoch_time)

  # We'll fall back if we fail a check of configuration, and just send to stderr
  # also keep the data we need for later if the curl fails, and we fallback then
  _fallback=0
  _fallback_extra_params="$*"
  httplog_check || _fallback=1
  if [ "$_fallback" == "1" ]; then
    httplog_fallback "$_message" "$_severity" "$_fallback_extra_params"
    return 1
  fi

  _kvpairs=""
  while [ -n "$1" ]; do
    _k="$( echo $1 | awk -F= '{ print $1 }' )"
    _v="$( echo $1 | awk -F= '{ print $2 }' )"
    ### need to put this early in the event so trailing comma not an issue
    _kvpairs=$(echo $_kvpairs ; echo "    \"$_k\": \"$_v\",")
    shift
  done

  # some defaults, if not set don't send the keys
  if [ -n "$_LOG_SOURCETYPE" ]; then
    _sourcetype="  \"sourcetype\": \"$_LOG_SOURCETYPE\","
  else
    _sourcetype=""
  fi
  if [ -n "$_LOG_INDEX" ]; then
    _index="  \"index\": \"$_LOG_INDEX\","
  else
    _index=""
  fi

  log_message=$(
cat <<EOM
{
  "time": "$_current_time",
  "host": "$fqdn",
  "source": "$_LOG_SOURCE",
  $_sourcetype
  $_index
  "event": {
    "severity": "$_severity",
    $_kvpairs
    "message": "$_message"
  }
}
EOM
)
  #echo $log_message
  /usr/bin/curl -k $_LOG_TARGET_URI -H "Authorization: Splunk $_LOG_TOKEN" -d "$log_message" 2>&1 > /dev/null
  RV=$?
  if [ "$RV" != "0" ]; then
    httplog_fallback "Curl failed, resending message through fallback mechanism" ERROR
    httplog_fallback "$_message" "$_severity" "$_fallback_extra_params"
  fi
}


# param 1 is filename to send, param 2 is severity, param 3+ is key=value to include
function httplog_file_contents() {
  # get the message
  _filename=$1
  shift
  if [ -z "$_filename" ]; then
    echo "ERROR: empty filename provided to httplog" >&2
    _filename="(null)"
  fi

  _message="File contents for $_filename"

  # get severity or default it
  if [ -n "$1" ]; then
    _severity=$1
    shift
  else
    _severity="INFO"
  fi

  _current_time=$(httplog_get_epoch_time)

  # We'll fall back if we fail a check of configuration, and just send to stderr
  # also keep the data we need for later if the curl fails, and we fallback then
  _fallback=0
  _fallback_extra_params="$*"
  httplog_check || _fallback=1
  if [ "$_fallback" == "1" ]; then
    httplog_fallback "$_message (contents not included in fallback)" "$_severity" "$_fallback_extra_params"
    return 1
  fi

  _kvpairs=""
  while [ -n "$1" ]; do
    _k="$( echo $1 | awk -F= '{ print $1 }' )"
    _v="$( echo $1 | awk -F= '{ print $2 }' )"
    ### need to put this early in the event so trailing comma not an issue
    _kvpairs=$(echo $_kvpairs ; echo "    \"$_k\": \"$_v\",")
    shift
  done

  # some defaults, if not set don't send the keys
  if [ -n "$_LOG_SOURCETYPE" ]; then
    _sourcetype="  \"sourcetype\": \"$_LOG_SOURCETYPE\","
  else
    _sourcetype=""
  fi
  if [ -n "$_LOG_INDEX" ]; then
    _index="  \"index\": \"$_LOG_INDEX\","
  else
    _index=""
  fi

  # generate the message contents:
  _raw_contents=$(
  echo '['
  while IFS= read -r _line
  do
    cooked_line=$(echo $_line | sed -e 's/\"/\\\"/g')
    echo "\"${cooked_line}\","
  done < $_filename
  # emit empty line to work with extra comma, not ideal but it works
  echo "\"\""
  echo ']'
  )

  log_message=$(
cat <<EOM
{
  "time": "$_current_time",
  "host": "$fqdn",
  "source": "$_LOG_SOURCE",
  $_sourcetype
  $_index
  "event": {
    "severity": "$_severity",
    $_kvpairs
    "message": "$_message",
    "file_contents": $_raw_contents
  }
}
EOM
)
  #echo $log_message
  /usr/bin/curl -k $_LOG_TARGET_URI -H "Authorization: Splunk $_LOG_TOKEN" -d "$log_message" 2>&1 > /dev/null
  RV=$?
  if [ "$RV" != "0" ]; then
    httplog_fallback "Curl failed, resending message through fallback mechanism" ERROR
    httplog_fallback "$_message (contents not included in fallback)" "$_severity" "$_fallback_extra_params"
  fi
}
