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

WORKING_DIR=${1:-/root/kavesetup}

DOMAIN=`hostname -d`

shift 1

for NODE in $@; do
    lookup_longname=$(getent hosts "$NODE")
    lookups="$lookups"$'\n'"$lookup_longname"$'\t'$NODE
done

echo "$lookups" > "$WORKING_DIR/hosts"
