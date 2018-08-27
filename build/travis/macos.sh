#!/bin/bash

set -uxe

brew install squashfs
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-darwin-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
if [ -z "${TRAVIS_TAG:-}" ]; then
  version=$(grep VERSION lib/pharos/version.rb |cut -d "\"" -f2)
else
  version=${TRAVIS_TAG#"v"}
fi

package="pharos-cluster-darwin-amd64-${version}"
build/minify.sh && cd build/out
rubyc -o $package pharos-cluster
./$package version
cd ../..

# ship to github
if [ ! -z "${TRAVIS_TAG}" ]; then
  curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/darwin-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
  chmod +x /usr/local/bin/github-release
  /usr/local/bin/github-release upload \
      --user kontena \
      --repo pharos-cluster \
      --tag $TRAVIS_TAG \
      --name $package \
      --file build/out/$package
fi

mkdir -p upload
mv build/out/$package upload/
rm -rf build/out