#!/bin/sh

set -e

export DEBIAN_FRONTEND=noninteractive
apt-mark unhold kubectl kubeadm || echo "Nothing to unhold"
apt-get install -y "kubectl=${KUBE_VERSION}-00" "kubeadm=${KUBEADM_VERSION}-00"
apt-mark hold kubectl kubeadm

if ! dpkg -s nfs-common > /dev/null; then
    systemctl mask rpcbind
    apt-get install -y nfs-common
fi
