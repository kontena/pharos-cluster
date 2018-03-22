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

apt-mark unhold $DOCKER_PACKAGE
apt-get install -y $DOCKER_PACKAGE=$DOCKER_VERSION
apt-mark hold $DOCKER_PACKAGE
