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

VERSION=${1:-2.0-Beta}
KAVE_BLUEPRINT=${2:-"blueprint.json"}
KAVE_CLUSTER=${3:-"cluster.json.local"}
WORKING_DIR=${4:-"/root/kavesetup"}

"$WORKING_DIR"/AmbariKave-$VERSION/deployment/deploy_from_blueprint.py "$KAVE_BLUEPRINT" "$KAVE_CLUSTER" --verbose --not-strict
