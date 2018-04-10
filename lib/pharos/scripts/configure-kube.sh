#!/bin/bash

set -eu

if [ -e /etc/systemd/system/kubelet.service.d/5-pharos-etcd.conf ]; then
    # remove etcd config because it conflicts with kubeadm
    rm /etc/systemd/system/kubelet.service.d/5-pharos-etcd.conf
    systemctl stop kubelet || true
    systemctl daemon-reload
fi

apt-mark unhold kubelet kubectl kubeadm
apt-get install -y kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubeadm=${KUBEADM_VERSION}-00
apt-mark hold kubelet kubectl kubeadm