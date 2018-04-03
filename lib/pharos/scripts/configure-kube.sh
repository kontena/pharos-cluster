#!/bin/bash

set -eu

apt-mark unhold kubelet kubectl kubeadm
apt-get install -y kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00
apt-mark hold kubelet kubectl kubeadm