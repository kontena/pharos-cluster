#!/bin/bash

set -ex

cd /tmp
apt-get download kubeadm=${VERSION}-00
dpkg -i --ignore-depends=kubelet kubeadm_${VERSION}*.deb
rm -f kubeadm_${VERSION}*.deb