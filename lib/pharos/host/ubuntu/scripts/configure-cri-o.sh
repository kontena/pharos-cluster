#!/bin/sh

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

tmpfile=$(mktemp /tmp/crio-service.XXXXXX)
cat <<"EOF" >"${tmpfile}"
[Unit]
Description=Open Container Initiative Daemon
Documentation=https://github.com/kubernetes-incubator/cri-o
After=network-online.target

[Service]
Type=notify
Environment=GOTRACEBACK=crash
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
ExecStart=/usr/local/bin/crio \
          $CRIO_STORAGE_OPTIONS \
          $CRIO_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
TasksMax=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
OOMScoreAdjust=-999
TimeoutStartSec=0
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF

if diff "$tmpfile" /etc/systemd/system/crio.service > /dev/null ; then
    rm -f "$tmpfile"
else
    mv "$tmpfile" /etc/systemd/system/crio.service
fi

configure_container_runtime_proxy "crio"
orig_version=$(/usr/local/bin/crio -v || echo "0.0.0")
export DEBIAN_FRONTEND=noninteractive
apt-mark unhold cri-o
apt-get install -y --allow-downgrades -o "Dpkg::Options::=--force-confnew" cri-o="${CRIO_VERSION}-*"
apt-mark hold cri-o

orig_config=$(cat /etc/crio/crio.conf)
lineinfile "^stream_address =" "stream_address = \"${CRIO_STREAM_ADDRESS}\"" "/etc/crio/crio.conf"
lineinfile "^cgroup_manager =" "cgroup_manager = \"${CRIO_CGROUP_MANAGER}\"" "/etc/crio/crio.conf"
lineinfile "^log_size_max =" "log_size_max = 134217728" "/etc/crio/crio.conf"
lineinfile "^pause_image =" "pause_image = \"${IMAGE_REPO}\/pause:3.1\"" "/etc/crio/crio.conf"
lineinfile "^registries =" "registries = [ \"docker.io\"" "/etc/crio/crio.conf"
lineinfile "^insecure_registries =" "insecure_registries = [ $INSECURE_REGISTRIES" "/etc/crio/crio.conf"

if ! systemctl is-active --quiet crio; then
    if [ -f /etc/cni/net.d/100-crio-bridge.conf ] || [ -f /etc/cni/net.d/200-loopback.conf ]; then
        rm -f /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true
    fi
    systemctl daemon-reload
    systemctl enable crio
    systemctl start crio
else
    if [ -f /etc/cni/net.d/100-crio-bridge.conf ] || [ -f /etc/cni/net.d/200-loopback.conf ]; then
        rm -f /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true
        reload_systemd_daemon "crio"
        exit 0
    fi
    if systemctl status crio 2>&1 | grep -q 'changed on disk' ; then
        reload_systemd_daemon "crio"
        exit 0
    fi

    if [ "$orig_config" != "$(cat /etc/crio/crio.conf)" ]; then
        reload_systemd_daemon "crio"
        exit 0
    fi

    if [ "$orig_version" != "$(/usr/local/bin/crio -v)" ]; then
        reload_systemd_daemon "crio"
        exit 0
    fi
fi
