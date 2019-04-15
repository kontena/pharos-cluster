#!/bin/sh

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh
# shellcheck disable=SC1091
. /usr/local/share/pharos/el7.sh

set -e

yum_install_with_lock "kubectl" "$KUBE_VERSION"
yum_install_with_lock "kubeadm" "$KUBE_VERSION"

if needs-restarting -s | grep -q kubelet.service ; then
    systemctl daemon-reload
    systemctl restart kubelet
fi

# use KUBELET_EXTRA_ARGS from /etc/systemd/system/kubelet.service.d/11-pharos.conf instead
sed -i 's/^KUBELET_EXTRA_ARGS=/#\0/' /etc/sysconfig/kubelet

if systemctl is-active --quiet rpcbind; then
    systemctl stop rpcbind
    systemctl disable rpcbind
fi
