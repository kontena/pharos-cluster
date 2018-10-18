#!/bin/bash

set -ue

SERVER=${SERVER:-localhost:6443}

if ! grep -qF "server: https://$SERVER" /etc/kubernetes/kubelet.conf; then
  sed -i "s/server: .*/server: https:\/\/$SERVER/g" /etc/kubernetes/kubelet.conf /etc/kubernetes/bootstrap-kubelet.conf
  systemctl restart kubelet
fi
