#!/bin/bash 
###################################################
# Azure prepare machines script. 
#
# This script accepts a list of nodes as arguments
# these will be used to move and execute the 
# prepare_machine.sh script.
###################################################

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOMAIN=`hostname -d`

if [ -f /root/.ssh/id_rsa.pub ]; then 
  for NODE in "$@";
  do
    scp $DIR/prepare_machine.sh $NODE:
    scp /root/.ssh/id_rsa.pub $NODE:
    ssh -t $NODE sudo bash prepare_machine.sh
    ssh $NODE.$DOMAIN echo "done"
  done
else
  echo "ERROR. no public key found."
fi

