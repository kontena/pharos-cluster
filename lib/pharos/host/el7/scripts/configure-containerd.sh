#!/bin/sh

set -e


yum install -y libseccomp util-linux socat
DL_URL="https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CONTAINERD_VERSION}.linux-${CPU_ARCH}.tar.gz"
curl -sSL $DL_URL -o /tmp/cri-containerd.tar.gz
tar -C / -xzf /tmp/cri-containerd.tar.gz

mkdir -p /etc/containerd
cat <<EOF >/etc/containerd/config.toml
[plugins]
  [plugins.cri]
    stream_server_address = "${STREAM_ADDRESS}"
    stream_server_port = "10010"
    enable_selinux = false
    sandbox_image = "${IMAGE_REPO}/pause-${CPU_ARCH}:3.1"
    stats_collect_period = 10
    systemd_cgroup = false
    enable_tls_streaming = false
    max_container_log_line_size = 16384
EOF

if ! systemctl is-active --quiet containerd; then
    systemctl daemon-reload
    systemctl enable containerd
fi

systemctl restart containerd