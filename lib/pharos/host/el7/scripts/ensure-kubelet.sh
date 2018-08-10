#!/bin/sh

. /usr/local/share/pharos/util.sh
. /usr/local/share/pharos/el7.sh

set -e

mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_ARGS} --pod-infra-container-image=${IMAGE_REPO}/pause-${ARCH}:3.1
EOF

yum_install_with_lock "kubelet" $KUBE_VERSION

if ! systemctl is-active --quiet kubelet; then
    systemctl enable kubelet
    systemctl start kubelet
fi

if needs-restarting -s | grep -q kubelet.service ; then
    systemctl daemon-reload
    systemctl restart kubelet
fi