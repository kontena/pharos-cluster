#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh
# shellcheck disable=SC1091
. /usr/local/share/pharos/el7.sh

configure_container_runtime_proxy "docker"

if [ -z "$DOCKER_VERSION" ]; then
    docker info
    exit 0
fi

mkdir -p /etc/docker
cat <<EOF >/etc/docker/daemon.json
{
    "bridge": "none",
    "iptables": false,
    "ip-masq": false,
    "insecure-registries": $INSECURE_REGISTRIES
}
EOF

yum_install_with_lock "docker-ce" "${DOCKER_VERSION}"

if ! systemctl is-active --quiet containerd; then
    systemctl enable containerd
    systemctl start containerd
fi

if ! systemctl is-active --quiet docker; then
    systemctl enable docker
    systemctl start docker
fi
