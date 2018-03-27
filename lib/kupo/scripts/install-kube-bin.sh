#!/bin/sh
#
# Usage: KUBE_VERSION=... ARCH=... install-kube-bin.sh kubectl
#

set -ue

bin=$1
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

curl -sSL --fail --retry 3 -o $tmpdir/$bin.gz \
  https://dl.bintray.com/kontena/pharos-bin/kube/${KUBE_VERSION}/${bin}-${ARCH}.gz

gzip -dc $tmpdir/$bin.gz > $tmpdir/$bin

install -m 0755 -t /usr/local/bin $tmpdir/$bin
