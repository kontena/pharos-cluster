#!/bin/bash

set -ex


if [ "$(kubelet --version)" = "Kubernetes v<%= kube_version %>" ]; then
    exit 0
fi

apt-mark unhold kubelet kubectl
apt-get install -y kubelet=<%= kube_version %>-00 kubectl=<%= kube_version %>-00
apt-mark hold kubelet kubelet kubectl

# Get kubeadm binary directly
curl -o /usr/bin/kubeadm https://storage.googleapis.com/kubernetes-release/release/v<%= kubeadm_version %>/bin/linux/<%= arch %>/kubeadm
chmod +x /usr/bin/kubeadm