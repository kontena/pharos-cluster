#!/bin/sh

set -e

# we don't want to accidentally upgrade kubelet
if systemctl is-active --quiet kubelet; then
    exit 0
fi

mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_ARGS} --pod-infra-container-image=${IMAGE_REPO}/pause:3.1
EOF

export DEBIAN_FRONTEND=noninteractive
apt-mark unhold kubelet kubernetes-cni || echo "Nothing to unhold"
apt-get install -y "kubelet=${KUBE_VERSION}-00" "kubernetes-cni=${CNI_VERSION}-00"
apt-mark hold kubelet kubernetes-cni
