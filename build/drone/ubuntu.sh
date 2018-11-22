#!/bin/sh

set -ue

# build binary
apt-get update -y
apt-get install -y -q squashfs-tools build-essential ruby bison ruby-dev git-core texinfo curl
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-linux-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc

# Download updated SSL certs
mkdir -p data
curl -sL https://curl.haxx.se/ca/cacert.pem > data/cacert.pem

gem install bundler
version=${DRONE_TAG#"v"}
package="pharos-cluster-linux-amd64-${version}"
mkdir -p /root/.pharos/build
rubyc -o "$package" -d /root/.pharos/build --make-args=--silent pharos-cluster
rm -rf /root/.pharos/build
./"$package" version
