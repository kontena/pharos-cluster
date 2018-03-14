#!/bin/bash

set -ex

if [ "$(kubelet --version)" = "Kubernetes v<%= kube_version %>" ]; then
    exit 0
fi

apt-mark unhold kubelet kubeadm kubectl
apt-get install -y kubelet=<%= kube_version %>-00 kubeadm=<%= kube_version %>-00 kubectl=<%= kube_version %>-00
apt-mark hold kubelet kubelet kubeadm kubectl