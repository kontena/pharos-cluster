#!/bin/sh

set -ue

brew install squashfs
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-darwin-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
version=${TRAVIS_TAG#"v"}
package="pharos-cluster-darwin-amd64-${version}"
rubyc -o "$package" pharos-cluster
"./$package" version
rm -rf upload/
mkdir -p upload
mv "$package" upload/
