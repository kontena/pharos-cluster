#!/bin/bash

set -ex

if [ "$(kubelet --version)" = "Kubernetes v1.9.3" ]; then
    exit 0
fi

if [ ! -e /etc/apt/sources.list.d/kubernetes.list ]; then
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
fi

apt-get update
apt-mark unhold kubelet kubeadm kubectl
apt-get install -y kubelet=1.9.3-00 kubeadm=1.9.3-00 kubectl=1.9.3-00
apt-mark hold kubelet kubeadm kubectl