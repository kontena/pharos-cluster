#!/bin/sh

set -ue

# build binary
apt-get update -y
apt-get install -y -q squashfs-tools build-essential ruby bison ruby-dev git-core texinfo curl
curl -sL https://dl.bintray.com/kontena/ruby-packer/0.5.0-dev/rubyc-linux-amd64.gz | gunzip > /usr/local/bin/rubyc
chmod +x /usr/local/bin/rubyc
gem install bundler
version=${DRONE_TAG#"v"}
package="pharos-cluster-linux-amd64-${version}"
../../minify.sh && cd build/out
rubyc -o $package pharos-cluster
./$package version
cd ../..

# ship to github
curl -sL https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar -xjO > /usr/local/bin/github-release
chmod +x /usr/local/bin/github-release
/usr/local/bin/github-release upload \
    --user kontena \
    --repo pharos-cluster \
    --tag $DRONE_TAG \
    --name $package \
    --file build/out/$package