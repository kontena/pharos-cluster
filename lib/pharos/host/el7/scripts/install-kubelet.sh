#!/bin/sh

. /usr/local/share/pharos/util.sh

set -e

versionlock="/etc/yum/pluginconf.d/versionlock.list"
linefromfile "^0:kubelet-" $versionlock
linefromfile "^0:kubectl-" $versionlock
linefromfile "^0:kubeadm-" $versionlock

yum install -y kubelet-${KUBE_VERSION} kubectl-${KUBE_VERSION} kubeadm-${KUBEADM_VERSION}

lineinfile "^0:kubelet-" "0:kubelet-${KUBE_VERSION}-0.*" $versionlock
lineinfile "^0:kubectl-" "0:kubectl-${KUBE_VERSION}-0.*" $versionlock
lineinfile "^0:kubeadm-" "0:kubeadm-${KUBE_VERSION}-0.*" $versionlock

if systemctl is-active --quiet rpcbind; then
    systemctl stop rpcbind
    systemctl disable rpcbind
fi