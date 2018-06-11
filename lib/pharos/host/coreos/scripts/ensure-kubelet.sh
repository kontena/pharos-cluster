#!/bin/sh

set -e

mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos-kubelet.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/opt/bin/kubelet ${KUBELET_ARGS} --pod-infra-container-image=${IMAGE_REPO}/pause-${ARCH}:3.1
EOF

# Kubelet systemd unit
if [ ! -e /etc/systemd/system/kubelet.service ]; then
    cat <<EOF >/etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/
[Service]
ExecStart=/opt/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable kubelet
    systemctl start kubelet
fi

if ! which kubelet > /dev/null || [ "$(kubelet --version)" != "Kubernetes v${KUBE_VERSION}" ]; then
    mkdir -p /opt/bin
    tmpdir=$(mktemp -d)
    cd $tmpdir
    package="kubelet-${ARCH}"
    curl -sSLO "https://dl.bintray.com/kontena/pharos-bin/kube/${KUBE_VERSION}/${package}.gz"
    curl -sSLO "https://dl.bintray.com/kontena/pharos-bin/kube/${KUBE_VERSION}/${package}.gz.asc"
    gpg --verify "${package}.gz.asc" "${package}.gz"
    gunzip ${package}.gz
    mv $package /opt/bin/kubelet
    chmod +x /opt/bin/kubelet
    rm -rf $tmpdir
fi