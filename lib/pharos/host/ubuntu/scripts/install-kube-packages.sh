#!/bin/sh

set -e

export DEBIAN_FRONTEND=noninteractive
apt-mark unhold kubelet kubectl kubeadm
apt-get install -y kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubeadm=${KUBEADM_VERSION}-00
apt-mark hold kubelet kubectl kubeadm

if ! dpkg -s nfs-common > /dev/null; then
    systemctl mask rpcbind
    apt-get install -y nfs-common
fi