#!/bin/bash

set -e

reload_daemon() {
    if systemctl is-active --quiet docker; then
        systemctl daemon-reload
        systemctl restart docker
    fi
}

if [ -n "$HTTP_PROXY" ]; then
    mkdir -p /etc/systemd/system/docker.service.d
    cat <<EOF >/etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
EOF
    reload_daemon
else
    if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
        rm /etc/systemd/system/docker.service.d/http-proxy.conf
        reload_daemon
    fi
fi

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