#!/bin/bash

##############################################################################
#
# Copyright 2016 KPMG N.V. (unless otherwise stated)
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
##############################################################################

USER=$1 
PASS=$2

shift 2

retries=30
failed=false

key=/root/.ssh/id_rsa

ssh-keygen -f "$key" -t rsa -N ''

echo StrictHostKeyChecking$'\t'no > ~/.ssh/config 

#For some unknown reason an sshpass may fail; let's retry ad nauseam
for NODE in $@; do
	retries_node=$retries
    until sshpass -p "$PASS" ssh-copy-id -i "$key" root@"$NODE"; do
    		((retries_node--))
    		if [ $retries_node -eq 0 ]; then
    			(>&2 echo "Failing to upload SSH key for passless login from the ambari server to the '$NODE' node...")
    			failed=true
    			break
    		fi
    		sleep 60;
	done
done

if $failed; then exit 3; fi
exit 0
