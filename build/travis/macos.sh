#!/bin/sh

set -ue

brew install squashfs
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-darwin-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
rubyc -o pharos-cluster pharos-cluster
./pharos-cluster version

# ship to github
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/darwin-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release
/usr/local/bin/github-release upload \
    --user kontena \
    --repo pharos-cluster \
    --tag $TRAVIS_TAG \
    --name "pharos-cluster-darwin-amd64" \
    --file ./pharos-cluster