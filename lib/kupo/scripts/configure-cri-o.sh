#!/bin/sh

set -uex

mkdir -p /etc/systemd/system/crio.service.d
cat <<EOF >/etc/systemd/system/crio.service.d/10-cgroup.conf
[Service]
Environment='CRIO_STORAGE_OPTIONS=--cgroup-manager=cgroupfs --stream-address=<%= host.private_address ? host.private_address : host.address %> --pause-image=k8s.gcr.io/pause-<%= host.cpu_arch.name %>:3.1'
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
EOF

if [ ! -e /etc/apt/sources.list.d/projectatomic-ubuntu-ppa-xenial.list ]; then
    add-apt-repository ppa:projectatomic/ppa
    apt-get update -y
fi

apt-get install -y cri-o-<%= crio_version %>
systemctl enable crio
# remove unnecessary cni plugins
rm /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true
systemctl start crio
