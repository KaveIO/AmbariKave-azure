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
}

setup_vnc() {
    until which vncserver vncpasswd 2>&-; do
	sleep 1
	echo "Waiting until VNC is installed..."
    done
    local vncdir=/home/"$USER"/.vnc
    local vncpasswd=$vncdir/.passwd
    mkdir -p "$vncdir"
    echo "$PASS" | vncpasswd -f > "$vncpasswd"; chmod 600 "$vncpasswd"
    vncserver
}

extradisknode_setup

post_installation &
