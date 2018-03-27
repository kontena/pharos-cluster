#!/bin/bash

set -e

if [ "$(kubelet --version)" = "Kubernetes v$KUBE_VERSION" ]; then
    exit 0
fi

apt-mark unhold kubelet kubectl kubeadm
apt-get install -y kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00
apt-mark hold kubelet kubectl kubeadm