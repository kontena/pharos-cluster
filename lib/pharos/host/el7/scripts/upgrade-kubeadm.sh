#!/bin/bash

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

set -ex

if [ -x "/usr/local/bin/pharos-kubeadm-${VERSION}" ]; then
    exit
fi

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir"
yum install "kubeadm-${VERSION}" -y --downloadonly --downloaddir="$tmpdir" --disableplugin=versionlock
cd "$tmpdir"
rpm2cpio *kubeadm*.rpm | cpio -idmv
install -o root -g root -m 0755 -T ./usr/bin/kubeadm "/usr/local/bin/pharos-kubeadm-${VERSION}"
rm -rf "$tmpdir"
"/usr/local/bin/pharos-kubeadm-${VERSION}" version
