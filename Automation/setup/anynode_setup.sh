#!/bin/bash

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
    
    wget -O "$WORKING_DIR/scripts.zip" "$REPOSITORY"

    unzip -d "$WORKING_DIR/temp" "$WORKING_DIR/scripts.zip" 

    mkdir "$WORKING_DIR/$DESTDIR"

    mv "$WORKING_DIR"/temp/*/* "$WORKING_DIR/$DESTDIR"

    rm -rf "$WORKING_DIR"/temp "$WORKING_DIR/scripts.zip"

    chmod -R +x "$WORKING_DIR/$DESTDIR/Automation/setup"
}

function install_packages {
    yum install -y epel-release

    yum install -y sshpass pdsh

    yum install -y rpcbind
}

function change_rootpass {
    echo root:$PASS | chpasswd
}

function configure_swap {
    local swapfile=/mnt/resource/swap$SWAP_SIZE

    fallocate -l "$SWAP_SIZE" "$swapfile"

    chmod 600 "$swapfile"

    mkswap "$swapfile"

    swapon "$swapfile"

    echo -e "$swapfile\tnone\tswap\tsw\t0\t0" >> /etc/fstab
}

function update_hostname {
    #The FreeIPA client installation depends on `uname -n` to provide a fqdn. This script updates your  /etc/sysconfig/network file so the hostname there matches your fqdn. Without this the FreeIPA clients will end up using the local names such as 'gate' and 'ambari' and the communication will fail.
    #To be fixed in KAVE (FreeIPA client installation wrapper)

   local file="/etc/sysconfig/network"
   local hostname=`hostname -s`
   local fqdn=`hostname -f`

   sed -i "s/^HOSTNAME=$hostname$/HOSTNAME=$fqdn/g" $file
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

install_packages

change_rootpass

configure_swap

update_hostname

disable_iptables

disable_selinux


