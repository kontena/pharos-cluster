#!/bin/sh

set -e

export DEBIAN_FRONTEND=noninteractive
apt-mark unhold kubelet kubectl kubeadm || echo "Nothing to unhold"
apt-get install -y "kubelet=${KUBE_VERSION}-00" "kubectl=${KUBE_VERSION}-00" "kubeadm=${KUBEADM_VERSION}-00"
apt-mark hold kubelet kubectl kubeadm

# use KUBELET_EXTRA_ARGS from /etc/systemd/system/kubelet.service.d/11-pharos.conf instead
sed -i 's/^KUBELET_EXTRA_ARGS=/#\0/' /etc/default/kubelet

if ! dpkg -s nfs-common > /dev/null; then
    systemctl mask rpcbind
    apt-get install -y nfs-common
fi
