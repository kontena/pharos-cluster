#!/bin/bash

set -ex

if [ $(kubeadm version -o short) = "v${VERSION}" ]; then
    exit
fi

cd /tmp
export DEBIAN_FRONTEND=noninteractive
apt-get download kubeadm=${VERSION}-00
dpkg -i --ignore-depends=kubelet kubeadm_${VERSION}*.deb
rm -f kubeadm_${VERSION}*.deb