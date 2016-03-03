#!/bin/bash

PWD=`pwd`
TEMPLATE=`basename $PWD`
CLUSTER_FILE="$PWD/$TEMPLATE.cluster.json"
DOMAIN=`hostname -d`

if [ -f "$CLUSTER_FILE" ]; then
  sed -r s/kave\.io/$DOMAIN/g $CLUSTER_FILE > $CLUSTER_FILE.local
else 
  echo "$CLUSTER_FILE does not exist"
fi 
