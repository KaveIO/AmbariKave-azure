#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

RELEASE=${1:-release-$(date +%Y-%m-%d)}

TEMPLATE=Artifacts/mainTemplate.json

git checkout -b $RELEASE
sed -i s/master/$RELEASE/g $TEMPLATE

git add $TEMPLATE
git commit -m "Tied the code in the release branch to the release branch."

git push origin $RELEASE
git branch --set-upstream-to=origin/$RELEASE $RELEASE

git tag $RELEASE
git push origin refs/tags/$RELEASE

git checkout master

zip "$DIR"/kave_on_azure-$RELEASE.zip "$DIR"/../Artifacts/*
