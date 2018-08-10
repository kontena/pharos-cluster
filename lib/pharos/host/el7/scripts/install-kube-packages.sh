#!/bin/sh

. /usr/local/share/pharos/util.sh
. /usr/local/share/pharos/el7.sh

set -e

yum_install_with_lock "kubelet" $KUBE_VERSION
yum_install_with_lock "kubectl" $KUBE_VERSION
yum_install_with_lock "kubeadm" $KUBE_VERSION

# use KUBELET_EXTRA_ARGS from /etc/systemd/system/kubelet.service.d/11-pharos.conf instead
sed -i 's/^KUBELET_EXTRA_ARGS=/#\0/' /etc/sysconfig/kubelet

if systemctl is-active --quiet rpcbind; then
    systemctl stop rpcbind
    systemctl disable rpcbind
fi