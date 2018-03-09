#!/bin/sh

set -ue

mkdir -p /etc/systemd/system/crio.service.d
cat <<EOF >/etc/systemd/system/crio.service.d/10-cgroup.conf
[Service]
Environment=CRIO_STORAGE_OPTIONS=--cgroup-manager=cgroupfs
EOF

add-apt-repository ppa:projectatomic/ppa
apt-get update -y
apt-get install -y cri-o-1.9
systemctl enable crio
systemctl start crio
