#!/bin/sh

set -e

reload_daemon() {
    if systemctl is-active --quiet crio; then
        systemctl daemon-reload
        systemctl restart crio
    fi
}

mkdir -p /etc/systemd/system/crio.service.d
cat <<EOF >/etc/systemd/system/crio.service.d/10-cgroup.conf
[Service]
Environment='CRIO_STORAGE_OPTIONS=--cgroup-manager=cgroupfs --stream-address=$CRIO_STREAM_ADDRESS --pause-image=${IMAGE_REPO}/pause-${CPU_ARCH}:3.1'
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
EOF

if [ -n "$HTTP_PROXY" ]; then
    cat <<EOF >/etc/systemd/system/crio.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
EOF
    reload_daemon
else
    if [ -f /etc/systemd/system/crio.service.d/http-proxy.conf ]; then
        rm /etc/systemd/system/crio.service.d/http-proxy.conf
        reload_daemon
    fi
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y cri-o-$CRIO_VERSION
systemctl enable crio
# remove unnecessary cni plugins
rm /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true
systemctl start crio

# Install crictl binary if needed


if ! which crictl > /dev/null || [ "$(crictl -v)" != "$CRICTL_VERSION" ]; then
    # Not installed or wrong version
    curl -sSL https://bintray.com/kontena/pharos-bin/download_file?file_path=crictl-v${CRICTL_VERSION}-linux-${CPU_ARCH}.tar.gz -o /tmp/crictl.tar.gz
    curl -sSL https://bintray.com/kontena/pharos-bin/download_file?file_path=crictl-v${CRICTL_VERSION}-linux-${CPU_ARCH}.tar.gz.asc -o /tmp/crictl.tar.gz.asc
    gpg --verify /tmp/crictl.tar.gz.asc /tmp/crictl.tar.gz
    tar xzf /tmp/crictl.tar.gz
    install -m 755 -o root -g root crictl /usr/local/bin/crictl && rm crictl
fi
