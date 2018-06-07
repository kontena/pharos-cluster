#!/bin/sh

set -e

mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_ARGS} --cgroup-driver=systemd --pod-infra-container-image=${IMAGE_REPO}/pause-${ARCH}:3.1
EOF

yum install -y kubelet-${KUBE_VERSION}

if ! systemctl is-active --quiet kubelet; then
    systemctl enable kubelet
    systemctl start kubelet
fi