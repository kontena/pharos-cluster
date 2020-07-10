#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

configure_container_runtime_proxy "containerd"

if [ -z "$CONTAINERD_VERSION" ]; then
    containerd -v
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

apt-mark unhold containerd.io || echo "Nothing to unhold"
if dpkg -l docker-ce ; then
    apt-get install -y "containerd.io=$CONTAINERD_VERSION*" || echo "Cannot install specific version, keeping the current one"
else
    apt-get install -y "containerd.io=$CONTAINERD_VERSION*"
fi
apt-mark hold containerd.io

lineinfile "^disabled_plugins =" "disabled_plugins = []" "/etc/containerd/config.toml"

if ! systemctl is-active --quiet containerd; then
    systemctl enable containerd
    systemctl start containerd
fi
