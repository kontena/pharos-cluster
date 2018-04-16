#!/bin/bash

set -e

if [ -e /etc/kubernetes/manifests/etcd.yaml ]; then
  # shutdown etcd
  rm /etc/kubernetes/manifests/etcd.yaml
  while nc -z localhost 2379; do
    sleep 1
  done
  # shutdown control plane
  rm /etc/kubernetes/manifests/kube-*.yaml
  while nc -z localhost 6443; do
    sleep 1
  done
  # trigger new kubeadm init
  rm /etc/kubernetes/admin.conf
  # reconfigure
  sed -i "s/${PEER_IP}/localhost/g" /etc/kubernetes/controller-manager.conf
  sed -i "s/${PEER_IP}/localhost/g" /etc/kubernetes/kubelet.conf
  sed -i "s/${PEER_IP}/localhost/g" /etc/kubernetes/scheduler.conf
  # trigger new certs
  rm /etc/kubernetes/pki/apiserver.*
  rm /etc/kubernetes/pki/front-proxy-*
  systemctl restart kubelet
fi