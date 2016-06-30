#!/bin/bash

USER=$1 
PASS=$2

shift 2

key=/root/.ssh/id_rsa

ssh-keygen -f "$key" -t rsa -N ''

echo StrictHostKeyChecking$'\t'no > ~/.ssh/config 

#For some unknown reason a sshpass may fail; let's retry a reasonable number of times
for i in `seq 1 10`; do
    for NODE in $@; do
	sshpass -p "$PASS" ssh-copy-id -i "$key" root@"$NODE"
    done
    sleep 10
done
