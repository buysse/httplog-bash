# httplog-bash
Bash function to do Splunk HTTP Event Collector from a shell script. This uses the JSON endpoint introduced with Splunk 6.3.x.  No warranty included, and some functions may not completely test for shell metacharacters.

Scripts will fall back to using stderr output if it can't connect to Splunk.  This was originally written for use from scripted inputs in Splunk that abused things in strange ways, and I wanted more detailed logging than simple stdout.  

# Usage example

```sh
# Include the file
. helpers.sh

# set up required vars
httplog_set_token $splunk_token
httplog_set_target https://httpevent-splunk:8088/services/collector/event

# Send a log message at DEBUG severity - severity if not included is INFO
httplog "This is a message for the log" DEBUG

# Send extra key-value pairs with the message, in this case captured output and return code from another command
httplog "Test message" ERROR return_code=$? output="$output"

# Send the full contents of a file
httplog_file_contents /tmp/output.log WARNING 

# License

Copyright 2017 Joshua Buysse (buysse@gmail.com)

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
