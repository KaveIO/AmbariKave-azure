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
    initialize_hdfs
    setup_vnc
    setup_xrdp
}

initialize_hdfs() {
    until which hadoop 2>&- && hadoop fs -ls / 2>&-; do
	sleep 60
	echo "Waiting until HDFS service is up and running..."
    done
    su - hdfs -c "hadoop fs -mkdir -p /user/$USER; hadoop fs -chown $USER:$USER /user/$USER"
}

setup_vnc() {
    until which vncserver vncpasswd 2>&-; do
	sleep 60
	echo "Waiting until VNC is installed..."
    done
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

extradisknode_setup

#Why should this be in the background? The ambari node depends as a resource on the rest of the nodes. Whether for bug or feature, Azure waits for the creation of the dependent VMs, not for their setups, to complete. In case this behavior is corrected in the future, and this should be the case IMHO, this script will return and give the greenlight to the provision of the ambari node.
#Why it is not? Because actually Azure does not enforce dependency on the setup, plus we are sure that when the deployment on Azure is shown as Completed we are really ready to connect.
post_installation
