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

apt-mark unhold <%= docker_package %>
apt-get install -y <%= docker_package %>=<%= docker_version %>
apt-mark hold <%= docker_package %>
