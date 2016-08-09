#!/bin/bash

SUBSCRIPTION_ID=$1

PUB_CERT=koapubcert.pem

azure config mode arm
azure login

#https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-connect/#comment-2812368170

tenantId=$(azure account show -s $SUBSCRIPTION_ID --json | grep tenant | cut -d\" -f4)

openssl req -x509 -days 3650 -newkey rsa:2048 -out $PUB_CERT -nodes -subj '/CN=koaht'

cat privkey.pem $PUB_CERT > koahtcert.pem

pubkey=$(cat $PUB_CERT | grep -v '^-----')

azure ad sp create -n "koaht" --home-page "https://github.com/KaveIO/AmbariKave-azure" -i "https://github.com/KaveIO/AmbariKave-azure" --key-value $pubkey


