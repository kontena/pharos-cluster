#!/bin/bash

set -eu

if [ -e /etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf ]; then
    # remove kubelet config because it conflicts with kubeadm
    rm /etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
    systemctl daemon-reload
fi