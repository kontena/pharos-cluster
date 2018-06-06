#!/bin/sh

set -e

apt-get install -y kubelet-${KUBE_VERSION} kubectl-${KUBE_VERSION} kubeadm-${KUBEADM_VERSION}

if systemctl is-active --quiet rpcbind; then
    systemctl stop rpcbind
    systemctl disable rpcbind
fi