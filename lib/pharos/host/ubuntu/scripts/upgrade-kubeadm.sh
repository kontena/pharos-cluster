#!/bin/bash

set -ex

[ -x "/usr/local/bin/pharos-kubeadm-${VERSION}" ] && exit

BIN_URL="https://dl.bintray.com/kontena/pharos-bin/kube/${VERSION}/kubeadm-${ARCH}.gz"

curl -fsSL "https://bintray.com/user/downloadSubjectPublicKey?username=bintray" | gpg --import
curl -fsSL "$BIN_URL" -o /tmp/kubeadm.gz
curl -fsSL "${BIN_URL}.asc" -o /tmp/kubeadm.gz.asc
gpg --verify /tmp/kubeadm.gz.asc /tmp/kubeadm.gz
gunzip /tmp/kubeadm.gz
install -o root -g root -m 0755 -T /tmp/kubeadm "/usr/local/bin/pharos-kubeadm-${VERSION}"
rm /tmp/kubeadm /tmp/kubeadm.gz.asc
