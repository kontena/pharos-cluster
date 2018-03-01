#!/bin/bash

set -e

mkdir -p /etc/docker
cat <<EOF >/etc/docker/daemon.json
{
    "storage-driver": "overlay2",
    "iptables": false,
    "ip-masq": false,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    }
}
EOF

if [ ! -e /etc/apt/sources.list.d/docker.list ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/docker.list
deb https://download.docker.com/linux/ubuntu xenial stable
EOF
fi

apt-get update
apt-mark unhold docker-ce
apt-get install -y docker-ce=17.03.2~ce-0~ubuntu-xenial
apt-mark hold docker-ce