#!/bin/sh

set -ue

export PHAROS_NON_OSS=true
export HOMEBREW_NO_AUTO_UPDATE=1

brew install squashfs
brew install openssl || brew upgrade openssl || true

curl -sL https://curl.haxx.se/ca/cacert.pem > /usr/local/etc/openssl/cacert.pem

curl -sL https://github.com/kontena/ruby-packer/releases/download/0.5.0%2Bextra7/rubyc-0.5.0+extra7-osx-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc

version=${TRAVIS_TAG#"v"}
package="pharos-cluster-darwin-amd64-${version}"
rubyc --openssl-dir=/usr/local/etc/openssl -o "$package" --make-args=--silent pharos
./"$package" version

rm -rf upload/
mkdir -p upload
mv "$package" upload/
