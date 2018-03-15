#!/bin/bash

set -ex


if [ "$(kubelet --version)" = "Kubernetes v<%= kube_version %>" ]; then
    exit 0
fi

apt-mark unhold kubelet kubeadm kubectl
apt-get install -y kubelet=<%= kube_version %>-00 kubectl=<%= kube_version %>-00
apt-mark hold kubelet kubelet kubeadm kubectl

# Get kubeadm binary directly
arch=`uname -m`
case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) echo "$arch not supported architecture, exiting..."
        exit 11
        ;;
esac
curl -o /usr/bin/kubeadm https://storage.googleapis.com/kubernetes-release/release/<%= kubeadm_version %>/bin/linux/$arch/kubeadm
chmod +x /usr/bin/kubeadm