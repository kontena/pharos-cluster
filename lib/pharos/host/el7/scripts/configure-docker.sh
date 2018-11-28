#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

configure_container_runtime_proxy "docker"

if [ -z "$DOCKER_VERSION" ]; then
    docker info
    exit 0
fi

mkdir -p /etc/docker
cat <<EOF >/etc/docker/daemon.json
{
    "live-restore": true,
    "iptables": false,
    "ip-masq": false,
    "insecure-registries": $INSECURE_REGISTRIES
}
EOF

yum install --enablerepo="${DOCKER_REPO_NAME}" -y "docker-${DOCKER_VERSION}"

if ! systemctl is-active --quiet docker; then
    systemctl enable docker
    systemctl start docker
fi
