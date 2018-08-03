#!/bin/sh

set -e

. /usr/local/share/pharos/util.sh

yum install -y conntrack-tools libseccomp gpgme libassuan

reload_daemon() {
    if systemctl is-active --quiet crio; then
        systemctl daemon-reload
        systemctl restart crio
    fi
}

tmpfile=$(mktemp /tmp/crio-service.XXXXXX)
cat <<"EOF" >${tmpfile}
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

if diff $tmpfile /etc/systemd/system/crio.service > /dev/null ; then
    rm $tmpfile
else
    mv $tmpfile /etc/systemd/system/crio.service
fi

mkdir -p /etc/systemd/system/crio.service.d
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

if [ ! "$(cat /etc/crio/.version)" = "$CRIO_VERSION" ]; then
    DL_URL="https://dl.bintray.com/kontena/pharos-bin/cri-o/cri-o-v${CRIO_VERSION}-linux-amd64.tar.gz"
    curl -sSL $DL_URL -o /tmp/cri-o.tar.gz
    curl -sSL "${DL_URL}.asc" -o /tmp/cri-o.tar.gz.asc
    gpg --verify /tmp/cri-o.tar.gz.asc /tmp/cri-o.tar.gz
    tar -C / -xzf /tmp/cri-o.tar.gz
    rm /tmp/cri-o.tar.gz /tmp/cri-o.tar.gz.asc
    echo $CRIO_VERSION > /etc/crio/.version 
fi

rm -f /etc/cni/net.d/100-crio-bridge.conf /etc/cni/net.d/200-loopback.conf || true

orig_config=$(cat /etc/crio/crio.conf)
lineinfile "^stream_address =" "stream_address = \"${CRIO_STREAM_ADDRESS}\"" "/etc/crio/crio.conf"
lineinfile "^cgroup_manager =" "cgroup_manager = \"systemd\"" "/etc/crio/crio.conf"
lineinfile "^log_size_max =" "log_size_max = 134217728" "/etc/crio/crio.conf"
lineinfile "^pause_image =" "pause_image = \"${IMAGE_REPO}/pause-${CPU_ARCH}:3.1\"" "/etc/crio/crio.conf"
lineinfile "^registries =" "registries = [ \"docker.io\"" "/etc/crio/crio.conf"

if ! systemctl is-active --quiet crio; then
    systemctl daemon-reload
    systemctl enable crio
    systemctl start crio
else 
    if systemctl status crio 2>&1 | grep -q 'changed on disk' ; then
        reload_daemon
    fi

    if [ "$orig_config" != "$(cat /etc/crio/crio.conf)" ]; then
        reload_daemon
    fi
fi