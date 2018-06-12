#!/bin/sh

. /usr/local/share/pharos/util.sh
. /usr/local/share/pharos/el7.sh

set -e

yum_install_with_lock "kubelet" $KUBE_VERSION
yum_install_with_lock "kubectl" $KUBE_VERSION
yum_install_with_lock "kubeadm" $KUBE_VERSION

if systemctl is-active --quiet rpcbind; then
    systemctl stop rpcbind
    systemctl disable rpcbind
fi