#!/bin/bash

set -e

mkdir -p /etc/docker
cat <<EOF >/etc/docker/daemon.json
{
    "storage-driver": "overlay2",
    "live-restore": true,
    "iptables": false,
    "ip-masq": false,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    }
}
EOF

if [ -n "$HTTP_PROXY" ]; then
    mkdir -p /etc/systemd/system/docker.service.d
    cat <<EOF >/etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
EOF
fi

export DEBIAN_FRONTEND=noninteractive

apt-mark unhold $DOCKER_PACKAGE
apt-get install -y $DOCKER_PACKAGE=$DOCKER_VERSION
apt-mark hold $DOCKER_PACKAGE
