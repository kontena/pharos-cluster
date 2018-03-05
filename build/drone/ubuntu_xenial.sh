#!/bin/sh

set -ue

# build binary
apt-get update -y
apt-get install -y -q squashfs-tools build-essential ruby bison ruby-dev git-core curl
curl -sL http://enclose.io/rubyc/rubyc-linux-x64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
gem install bundler
bundle install --path bundler
rubyc -o kupo kupo
./kupo version --all

# ship to github
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release
/usr/local/bin/github-release upload \
    --user kontena \
    --repo kupo \
    --tag $DRONE_TAG \
    --name "kupo-linux-amd64" \
    --file ./kupo