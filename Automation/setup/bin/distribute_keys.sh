#!/bin/bash

USER=$1 
PASS=$2

shift 2

key=/root/.ssh/id_rsa

ssh-keygen -f "$key" -t rsa -N ''

echo StrictHostKeyChecking$'\t'no > ~/.ssh/config 

#For some unknown reason a sshpass may fail; let's retry ad nauseam
for NODE in $@; do
    until sshpass -p "$PASS" ssh-copy-id -i "$key" root@"$NODE"; do sleep 60; done
done

