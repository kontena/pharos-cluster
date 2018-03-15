#!/bin/bash

set -ex


if [ "$(kubelet --version)" = "Kubernetes v<%= kube_version %>" ]; then
    exit 0
fi

apt-mark unhold kubelet kubeadm kubectl
apt-get install -y kubelet=<%= kube_version %>-00 kubeadm=<%= kube_version %>-00 kubectl=<%= kube_version %>-00
apt-mark hold kubelet kubelet kubeadm kubectl

# Hack to get 1.10.beta.3 kubeadm in place
# Needed to be able to configure cri socket in the config file
# See: https://github.com/kubernetes/kubernetes/pull/59057
# FIXME Remove when we're using official 1.10 kubeadm
curl -o /usr/bin/kubeadm https://storage.googleapis.com/kubernetes-release/release/v1.10.0-beta.3/bin/linux/amd64/kubeadm
chmod +x /usr/bin/kubeadm