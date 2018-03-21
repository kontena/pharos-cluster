#!/bin/bash

set -ex

curl -sSL https://dl.bintray.com/kontena/pharos-bin/kube/<%= version %>/kubeadm-<%= arch %>.gz | gunzip > /usr/bin/kubeadm
chmod +x /usr/bin/kubeadm

