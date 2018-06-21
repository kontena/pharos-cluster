#!/bin/sh

. /usr/local/share/pharos/util.sh
. /usr/local/share/pharos/el7.sh

set -e

mkdir -p /etc/systemd/system/kubelet.service.d

cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_ARGS} --cgroup-driver=systemd --pod-infra-container-image=${IMAGE_REPO}/pause-${ARCH}:3.1
EOF

cat <<EOF >/etc/systemd/system/kubelet.service.d/11-cgroups.conf
[Service]

# https://github.com/kontena/pharos-cluster/issues/440
# the kubelet expects to find cpu+memory cgroups for the kubelet and docker services in order to report system container stats
# have systemd create per-service cpu+memory cgroups for the kubelet.service
# as a side effect, this will also create cpu+memory cgroups for all system.slice services, including docker.service
CPUAccounting=true
MemoryAccounting=true
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