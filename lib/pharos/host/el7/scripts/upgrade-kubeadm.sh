#!/bin/bash

. /usr/local/share/pharos/util.sh

set -ex

if [ $(kubeadm version -o short) = "v${VERSION}" ]; then
    exit
fi

versionlock="/etc/yum/pluginconf.d/versionlock.list"
linefromfile "^0:kubeadm-" $versionlock
yum install -y "kubeadm-${VERSION}"
lineinfile "^0:kubeadm-" "0:kubeadm-${VERSION}-0.*" $versionlock