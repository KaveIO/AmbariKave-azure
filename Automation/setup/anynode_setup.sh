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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REPOSITORY=$1
USER=$2
PASS=$3
DESTDIR=${4:-contents}
SWAP_SIZE=${5:-10g}
WORKING_DIR=${6:-/root/kavesetup}

function setup_repo {
    rm -rf "$WORKING_DIR"
    
    mkdir -p "$WORKING_DIR"
    
    wget --tries=10 --read-timeout=60 -O "$WORKING_DIR/scripts.zip" "$REPOSITORY"

    unzip -d "$WORKING_DIR/temp" "$WORKING_DIR/scripts.zip" 

    mkdir "$WORKING_DIR/$DESTDIR"

    mv "$WORKING_DIR"/temp/*/* "$WORKING_DIR/$DESTDIR"

    rm -rf "$WORKING_DIR"/temp "$WORKING_DIR/scripts.zip"

    AUTOMATION_DIR="$WORKING_DIR/$DESTDIR/Automation"
    
    chmod -R +x "$AUTOMATION_DIR/setup"
}

function patch_yum {
	configure_yum_repos
    amend_yum_conf
    use_fast_mirrors
}

configure_yum_repos() {
    #The 6.5 dirs were wiped out the default yum repo of OpenLogic, therefore we have to use the official repo. So yes 6.5 is still supported as the 6 branch still is, even if the latest-greatest is 6.8.
    local repodir=/etc/yum.repos.d
    rm $repodir/*
    cp "$AUTOMATION_DIR"/patch/CentOS-Official.repo $repodir
	#Appearently the Mongo repo has changed too, but since this is to be fixed in KAVE, let's just add the new repo with a higher priority
    yum install -y yum-plugin-priorities
    cp "$AUTOMATION_DIR"/patch/mongodb.new.repo $repodir
    #This is needed because the Mongo Ambari service install drops the file if not there
    touch $repodir/mongodb.repo
}

amend_yum_conf() {
    #Not sure why is this but yum tries to use v6 pretty randomly - once I failed possibly because of this, let's just force v4. Also, let's just try forever to install a package - if an install
    #does not happen we are in trouble anyway.
    echo "ip_resolve=4" >> /etc/yum.conf
    echo "retries=0" >> /etc/yum.conf
}

use_fast_mirrors() {
	yum install -y yum-plugin-fastestmirror
	local plugindir=/etc/yum/pluginconf.d/
	mkdir -p $plugindir
	cp "$AUTOMATION_DIR"/patch/fastestmirror.conf $plugindir
}

function install_packages {
    yum install -y epel-release
    yum clean all
    
    yum install -y sshpass pdsh

    yum install -y rpcbind

    yum install -y ipa-server ipa-client
}

function patch_ipa {
    #Patch the installed FreeIPA; as this is a regular yum install Ambari will try to reinstall it but it will not be overwritten of course. The installation of the server on client nodes too must be taken as a precaution - if the user installs the unpatched server afterwards then we can have problems.
    #Why this? In different parts of the code the common name (CN) is build concatenating the DNS domain name and the string "Certificate Authority", and in our case due to Azure long DNSDN the field ends up to be longer than 64 chars which is the RFC-defined standard maximum. This suffix is added as a naming convention, so we cannot just drop it, rather amend it.

    grep -IlR "Certificate Authority" /usr/lib/python2.6/site-packages/ipa* | xargs sed -i 's/Certificate Authority/CA/g'
    #To be fixed in FreeIPA (ideally, but it won't be the case)
    #To be fixed in KAVE (installation will refuse to continue if the total string "FQDN + "Certificate Authority" is longer than 64 OR it gives the option to apply this patch
}

function change_rootpass {
    echo root:$PASS | chpasswd
}

function disable_iptables {
    #The deploy_from_blueprint KAVE script performs a number of commands on the cluster hosts. Among these, it reads like iptables is stopped, but not permanently. It must be off as otherwise, at least a priori, the FreeIPA clients cannot talk to eachother. We want these changes to be permanent in the (remote) case that the system goes down or is rebooted - otherwise KAVE will stop working afterwards.
    #To be fixed in KAVE
    service iptables stop
    chkconfig iptables off
}

function disable_selinux {
    #Same story as iptables, SELinux must be permanently off but it is only temporary disabled in the blueprint deployment script.
    #To be fixed in KAVE
    echo 0 >/selinux/enforce
    sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
}

setup_repo

patch_yum

install_packages

patch_ipa

change_rootpass

disable_iptables

disable_selinux
