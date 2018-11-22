#!/bin/sh

set -ue

rm -rf non-oss/

brew install squashfs
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-darwin-amd64.gz | gunzip > /usr/local/bin/rubyc
curl -sL https://curl.haxx.se/ca/cacert.pem > data/cacert.pem
chmod +x /usr/local/bin/rubyc

# Download updated SSL certs
mkdir -p data
curl -sL https://curl.haxx.se/ca/cacert.pem > data/cacert.pem

version=${TRAVIS_TAG#"v"}
package="pharos-cluster-darwin-amd64-${version}+oss"
rubyc -o "$package" --make-args=--silent pharos-cluster
./"$package" version

rm -rf upload/
mkdir -p upload
mv "$package" upload/
