#!/bin/bash

set -ex

if [ "$(kubelet --version)" = "Kubernetes v<%= kube_version %>" ]; then
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
apt-get install -y kubelet=<%= kube_version %>-00 kubeadm=<%= kube_version %>-00 kubectl=<%= kube_version %>-00
apt-mark hold kubelet kubeadm kubectl