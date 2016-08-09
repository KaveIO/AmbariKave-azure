#!/bin/bash

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

if $failed; then return 3; fi
return 0
