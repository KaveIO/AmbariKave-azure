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

RELEASE=${1:-release-$(date +%Y-%m-%d)}

TEMPLATE="$DIR/../Artifacts/mainTemplate.json"

git checkout -b $RELEASE
echo "Warning, assuming BSD sed, remove '' for GNU"
sed -i '' s/master/$RELEASE/g $TEMPLATE

git add $TEMPLATE
git commit -m "Tied the code in the release branch to the release branch."

git push origin $RELEASE
git branch --set-upstream-to=origin/$RELEASE $RELEASE

git tag $RELEASE
git push origin refs/tags/$RELEASE

cd "$DIR"/../Artifacts/
zip "$DIR"/kave_on_azure-$RELEASE.zip *

git checkout master
