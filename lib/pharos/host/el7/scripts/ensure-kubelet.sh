#!/bin/sh

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh
# shellcheck disable=SC1091
. /usr/local/share/pharos/el7.sh

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

yum_install_with_lock "kubernetes-cni" "$CNI_VERSION"
yum_install_with_lock "kubelet" "$KUBE_VERSION"

if ! systemctl is-active --quiet kubelet; then
    systemctl enable kubelet
    systemctl start kubelet
fi
