#!/bin/bash

set -ex

curl -sSL https://dl.bintray.com/kontena/pharos-bin/kube/${VERSION}/kubeadm-${ARCH}.gz | gunzip > /usr/bin/kubeadm
chmod +x /usr/bin/kubeadm

