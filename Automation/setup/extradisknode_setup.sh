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
DISK=$4
MOUNT=$5
DESTDIR=${6:-contents}
SWAP_SIZE=${7:-10g}
WORKING_DIR=${8-/root/kavesetup}

function anynode_setup {
    chmod +x "$DIR/anynode_setup.sh"
    
    "$DIR/anynode_setup.sh" "$REPOSITORY" "$USER" "$PASS" "$DESTDIR" "$SWAP_SIZE" "$WORKING_DIR"
}

function initialize_data_disk {
    "$WORKING_DIR/$DESTDIR/Automation/setup/bin/initialize_data_disk.sh" "$DISK" "$MOUNT"
}

anynode_setup

initialize_data_disk
