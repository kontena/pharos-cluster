#!/bin/sh

if [ "$(kubeadm version -o short)" != "v${KUBE_VERSION}" ]; then
  /opt/kontena/bin/install-kube-bin.sh kubeadm
fi
