#!/bin/bash

set -ex

[ -x "/usr/local/bin/pharos-kubeadm-${VERSION}" ] && exit

tmpdir=$(mktemp -d)
cd "$tmpdir"
apt-get download "kubeadm=${VERSION}*"
dpkg-deb -R kubeadm_"${VERSION}"*.deb kubeadm
install -o root -g root -m 0755 -T ./kubeadm/usr/bin/kubeadm "/usr/local/bin/pharos-kubeadm-${VERSION}"
rm -rf "$tmpdir"
"/usr/local/bin/pharos-kubeadm-${VERSION}" version
