#!/bin/sh

set -e

mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_ARGS}
EOF

export DEBIAN_FRONTEND=noninteractive
apt-mark unhold kubelet
apt-get install -y kubelet=${KUBE_VERSION}-00
apt-mark hold kubelet