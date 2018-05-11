#!/bin/sh

set -ue

mkdir -p /etc/systemd/system/crio.service.d
cat <<EOF >/etc/systemd/system/crio.service.d/10-cgroup.conf
[Service]
Environment='CRIO_STORAGE_OPTIONS=--cgroup-manager=cgroupfs --stream-address=$CRIO_STREAM_ADDRESS --pause-image=k8s.gcr.io/pause-${CPU_ARCH}:3.1'
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
EOF

DEBIAN_FRONTEND=noninteractive apt-get install -y cri-o-$CRIO_VERSION
systemctl enable crio
# remove unnecessary cni plugins
rm /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true
systemctl start crio

# Install crictl binary
CRICTL_DOWNLOAD_SHA="597a4db0289870d81d0377396ddaf4c23725a47b33b30856e6291c2b958786f3"
curl -sSL https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-${CPU_ARCH}.tar.gz -o /tmp/crictl.tar.gz
echo "$CRICTL_DOWNLOAD_SHA  /tmp/crictl.tar.gz" | shasum -a256 -c
tar xzf /tmp/crictl.tar.gz
install -m 755 -o root -g root crictl /usr/bin/crictl && rm crictl