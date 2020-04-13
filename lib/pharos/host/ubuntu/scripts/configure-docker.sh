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
    "storage-driver": "overlay2",
    "bridge": "none",
    "iptables": false,
    "ip-masq": false,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "insecure-registries": $INSECURE_REGISTRIES
}
EOF

export DEBIAN_FRONTEND=noninteractive

apt-mark unhold "$DOCKER_PACKAGE" || echo "Nothing to unhold"
if dpkg -l docker-ce ; then
    apt-get install -y "$DOCKER_PACKAGE=5:$DOCKER_VERSION*" || echo "Cannot install specific version, keeping the current one"
else
    apt-get install -y "$DOCKER_PACKAGE=5:$DOCKER_VERSION*"
fi
apt-mark hold "$DOCKER_PACKAGE"

if ! systemctl is-active --quiet containerd; then
    systemctl enable containerd
    systemctl start containerd
fi

if ! systemctl is-active --quiet docker; then
    systemctl enable docker
    systemctl start docker
fi
