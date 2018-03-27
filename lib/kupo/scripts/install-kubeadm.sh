#!/bin/bash

set -ex

curl -sSL https://dl.bintray.com/kontena/pharos-bin/kube/${VERSION}/kubeadm-${ARCH}.gz | gunzip > /usr/local/bin/kubeadm
chmod +x /usr/local/bin/kubeadm

