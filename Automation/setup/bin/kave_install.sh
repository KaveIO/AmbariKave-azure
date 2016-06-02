#!/bin/bash
#This is to be executed on the cluster node designated for ambari

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERSION=${1:-2.0-Beta}
WORKING_DIR=${2:-/root/kavesetup}

function patch_kave {
     #The FreeIPA client installation depends on `uname -n` to provide a fqdn. This script updates your  /etc/sysconfig/network file so the hostname there matches your fqdn. Without this the FreeIPA clients will end up using the local names such as 'gate' and 'ambari' and the communication will fail.
    #To be fixed in KAVE (FreeIPA client installation wrapper)
    cp "$WORKING_DIR"/contents/Automation/patch/freeipa.py "$WORKING_DIR"/AmbariKave-$VERSION/src/HDP/2.4.KAVE/services/FREEIPA/package/scripts
}

wget "https://github.com/KaveIO/AmbariKave/archive/$VERSION.zip" -O "$WORKING_DIR/$VERSION.zip"

unzip "$WORKING_DIR/$VERSION.zip" -d "$WORKING_DIR"

#To avoid conflicts with what the Kave installer installs
yum remove -y epel-release
yum remove -y sshpass pdsh

service iptables stop
chkconfig iptables off
cd "$WORKING_DIR/AmbariKave-$VERSION"
dev/install.sh
patch_kave
dev/patch.sh
ambari-server start
