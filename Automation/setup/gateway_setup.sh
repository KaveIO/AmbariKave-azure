#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REPOSITORY=$1
USER=$2
PASS=$3
DISK=$4
MOUNT=$5
DESTDIR=${6:-contents}
SWAP_SIZE=${7:-10g}
WORKING_DIR=${8-/root/kavesetup}

function extradisknode_setup {
    chmod +x "$DIR/extradisknode_setup.sh"
    
    "$DIR/extradisknode_setup.sh" "$REPOSITORY" "$USER" "$PASS" "$DISK" "$MOUNT" "$DESTDIR" "$SWAP_SIZE" "$WORKING_DIR"
}

function post_installation {
    setup_vnc
    setup_xrdp
    remove_gnomepackagekit &
    initialize_hdfs &
}

setup_vnc() {
	until which vncserver 2>&- && which vncpasswd 2>&-; do sleep 5; done
    local vncdir=/home/"$USER"/.vnc
    local vncpasswd=$vncdir/passwd
    su - $USER -c "
        mkdir -p \"$vncdir\"
        echo \"$PASS\" | vncpasswd -f > \"$vncpasswd\"; chmod 600 \"$vncpasswd\"
    "
    echo "VNCSERVERS=\"1:$USER\"" >> /etc/sysconfig/vncservers
    chkconfig vncserver on 
    service vncserver start 
}

setup_xrdp() {
    yum install -y xrdp
    sed -i "s/tsusers/$USER/" /etc/xrdp/sesman.ini
    chkconfig xrdp on
    service xrdp start
}

remove_gnomepackagekit() {
    until yum remove -y PackageKit; do sleep 60; done
}

initialize_hdfs() {
    until which hadoop 2>&- && hadoop fs -ls / 2>&-; do
		sleep 60
		echo "Waiting until HDFS service is up and running..."
    done
    su - hdfs -c "hadoop fs -mkdir -p /user/$USER; hadoop fs -chown $USER:$USER /user/$USER"
}

extradisknode_setup

post_installation
