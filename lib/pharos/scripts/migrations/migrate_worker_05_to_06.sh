#!/bin/bash

set -e

if grep -q "${PEER_IP}:6443" /etc/kubernetes/kubelet.conf; then
  # reconfigure
  sed -i "s/${PEER_IP}/localhost/g" /etc/kubernetes/kubelet.conf
  sed -i "s/${PEER_IP}/localhost/g" /etc/kubernetes/bootstrap-kubelet.conf
  systemctl restart kubelet
fi