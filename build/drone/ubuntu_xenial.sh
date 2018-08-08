#!/bin/sh

set -ue

# build binary
apt-get update -y
apt-get install -y -q squashfs-tools build-essential ruby bison ruby-dev git-core texinfo curl
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-linux-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
gem install bundler
rubyc -o pharos-cluster-linux-amd64 pharos-cluster
./pharos-cluster-linux-amd64 version
shasum -a 256 pharos-cluster-linux-amd64 > pharos-cluster-linux-amd64.sha256
# ship to github
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release
ls -1 pharos-cluster-linux-adm64 pharos-cluster-linux-amd64.sha256 | xargs -n1 -I{} -P0 -- \
  /usr/local/bin/github-release upload \
    --user kontena \
    --repo pharos-cluster \
    --tag $DRONE_TAG \
    --name {} \
    --file {} ::: pharos-cluster-linux-amd64 pharos-cluster-linux-amd64.shasum