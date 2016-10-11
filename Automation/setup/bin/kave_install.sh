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

#This is to be executed on the cluster node designated for ambari

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERSION=${1:-2.0-Beta}
WORKING_DIR=${2:-/root/kavesetup}

ARTIFACT_MD5="b7a4dca5d0a713d1a4bbd95978894f3d"

function download_kave {

	local artifact="$WORKING_DIR/$VERSION.zip"

	wget --tries=30 --read-timeout=60 "https://github.com/KaveIO/AmbariKave/archive/$VERSION.zip" -O "$artifact"
	local download_md5=$(md5sum "$artifact" | cut -d' ' -f1)
	test $ARTIFACT_MD5 = $download_md5

	unzip -o "$artifact" -d "$WORKING_DIR"

}

function patch_kave {
     
	#The FreeIPA client installation depends on `uname -n` to provide a fqdn. This script updates your  /etc/sysconfig/network file so the hostname there matches your fqdn. Without this the FreeIPA clients will end up using the local names such as 'gate' and 'ambari' and the communication will fail.
    #To be fixed in KAVE (FreeIPA client installation wrapper)
    cp "$WORKING_DIR"/contents/Automation/patch/freeipa.py "$WORKING_DIR"/AmbariKave-$VERSION/src/HDP/2.4.KAVE/services/FREEIPA/package/scripts

}

download_kave

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
