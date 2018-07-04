#!/bin/bash

set -ex

if [ $(kubeadm version -o short) = "v${VERSION}" ]; then
    exit
fi

BIN_URL="https://dl.bintray.com/kontena/pharos-bin/kube/${VERSION}/kubeadm-${ARCH}.gz"

curl -fsSL $BIN_URL -o /tmp/kubeadm.gz
curl -fsSL "${BIN_URL}.asc" -o tmp/kubeadm.gz.asc
gpg --verify /tmp/kubeadm.gz.asc /tmp/kubeadm.gz
gunzip /tmp/kubeadm.gz
install -o root -g root -m 0755 -t /usr/local/bin /tmp/kubeadm # XXX: overrides package version?
rm /tmp/kubeadm /tmp/kubeadm.gz.asc
