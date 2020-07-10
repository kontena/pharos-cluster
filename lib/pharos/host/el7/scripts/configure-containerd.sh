#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh
# shellcheck disable=SC1091
. /usr/local/share/pharos/el7.sh

configure_container_runtime_proxy "containerd"

if [ -z "$CONTAINERD_VERSION" ]; then
    docker info
    exit 0
fi

yum_install_with_lock "containerd.io" "${CONTAINERD_VERSION}"

lineinfile "^disabled_plugins =" "disabled_plugins = []" "/etc/containerd/config.toml"

if ! systemctl is-active --quiet containerd; then
    systemctl enable containerd
    systemctl start containerd
fi

if ! systemctl is-active --quiet containerd; then
    systemctl enable containerd
    systemctl start containerd
fi
