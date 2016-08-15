#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

RELEASE=${1:-release-$(date +%Y-%m-%d)}

git tag -d $RELEASE

git branch -D $RELEASE

git push origin :refs/heads/$RELEASE

git push origin :$RELEASE
