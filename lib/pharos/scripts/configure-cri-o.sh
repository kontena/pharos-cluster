#!/bin/sh

set -ue

mkdir -p /etc/systemd/system/crio.service.d
cat <<EOF >/etc/systemd/system/crio.service.d/10-cgroup.conf
[Service]
Environment='CRIO_STORAGE_OPTIONS=--cgroup-manager=cgroupfs --stream-address=$CRIO_STREAM_ADDRESS --pause-image=k8s.gcr.io/pause-${CPU_ARCH}:3.1'
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
EOF

apt-get install -y cri-o-$CRIO_VERSION
systemctl enable crio
# remove unnecessary cni plugins
rm /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true
systemctl start crio
