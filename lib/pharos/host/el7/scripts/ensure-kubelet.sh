#!/bin/sh

. /usr/local/share/pharos/util.sh

set -e

mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_ARGS} --cgroup-driver=systemd --pod-infra-container-image=${IMAGE_REPO}/pause-${ARCH}:3.1
EOF

versionlock="/etc/yum/pluginconf.d/versionlock.list"
linefromfile "^0:kubelet-" $versionlock
yum install -y kubelet-${KUBE_VERSION}
lineinfile "^0:kubelet-" "0:kubelet-${KUBE_VERSION}-0.*" $versionlock

if ! systemctl is-active --quiet kubelet; then
    systemctl enable kubelet
    systemctl start kubelet
fi

if needs-restarting -s | grep -q kubelet.service ; then
    systemctl daemon-reload
    systemctl restart kubelet
fi