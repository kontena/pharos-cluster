#!/bin/sh

set -e

if [ "$(ctr -v)" = "ctr github.com/containerd/containerd v${CONTAINERD_VERSION}" ]; then
    exit 0
fi

apt-get install -y libseccomp2
DL_URL="https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz"
curl -sSL $DL_URL -o /tmp/cri-containerd.tar.gz
tar -C / -xzf /tmp/cri-containerd.tar.gz

if ! systemctl is-active --quiet containerd; then
    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd
fi