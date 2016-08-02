#!/bin/bash
	
TEMPLATE=${1:-MainTemplate.json}
PARAMETERS=${2:-Parameters.json}
REGION=${3:-westeurope}
ALIAS=${4:-KaveTest}
USER=${5:-kaveadmin}
GATEWAY=${6:-gate}
AMBARINODE=${7:-ambari}
PREFIX=${8:-ht-}
CLUSTER_NAME=${9:-cluster}
AMBARI_USER=${10:-admin}
AMBARI_PASS=${11:-$AMBARI_USER}

#https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-connect/#comment-2812368170

azure config mode arm 

old_htrg=$(azure group list | grep -o "$PREFIX[0-9]*")
nr=$(echo $old_htrg | cut -d- -f2)

yes | azure group delete $old_htrg 

new_htrg=$PREFIX$((($nr+1)))

azure group create -n $new_htrg -l $REGION

azure group deployment create -f $TEMPLATE -e $PARAMETERS -g $new_htrg -n alias_$new_htrg

sleep 3600

gate_ip=$(azure vm show $new_htrg $GATEWAY | grep "Public IP address" | egrep -o "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}")

command='curl --netrc -H X-Requested-By:KoASetup -X'
cluster_url="http://$AMBARINODE:8080/api/v1/clusters/$CLUSTER_NAME"
ssh $USER@$gate_ip $command GET "$cluster_url/requests?fields=Requests" 2>&- | egrep -v "IN_PROGRESS|PENDING|QUEUED"
