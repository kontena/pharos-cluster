#!/bin/sh

set -ue

brew install squashfs
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-darwin-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
rubyc -o pharos-cluster-darwin-amd64 pharos-cluster
./pharos-cluster-darwin-amd64 version
shasum -a 256 pharos-cluster-darwin-amd64 > pharos-cluster-darwin-amd64.sha256

# ship to github
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/darwin-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release
ls -1 pharos-cluster-darwin-adm64 pharos-cluster-darwin-amd64.sha256 | xargs -n1 -I{} -P0 -- \
  /usr/local/bin/github-release upload \
    --user kontena \
    --repo pharos-cluster \
    --tag $TRAVIS_TAG \
    --name {} \
    --file {}