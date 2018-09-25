#!/bin/sh

set -ue

rm -rf non-oss/*

# build binary
apt-get update -y
apt-get install -y -q squashfs-tools build-essential ruby bison ruby-dev git-core texinfo curl
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-linux-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
gem install bundler
version=${DRONE_TAG#"v"}
package="pharos-cluster-linux-amd64-${version}+oss"
sudo mkdir /__enclose_io_memfs__
rubyc -o $package -d /__enclose_io_memfs__ pharos-cluster
./$package version
