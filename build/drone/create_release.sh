#!/bin/sh

set -ue

# ship to github
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release

if [[ $DRONE_TAG =~ .+-.+ ]]; then
    /usr/local/bin/github-release release \
        --user kontena \
        --repo kupo \
        --tag $DRONE_TAG \
        --name $DRONE_TAG \
        --description "Pre-release, only for testing"
        --pre-release
else
    /usr/local/bin/github-release release \
        --user kontena \
        --repo kupo \
        --tag $DRONE_TAG \
        --name $DRONE_TAG
fi