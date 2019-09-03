#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

mkdir -p /etc/systemd/system/firewalld.service.d
cat <<EOF >/etc/systemd/system/firewalld.service.d/10-pharos.conf
[Service]
Restart=always
Before=kubelet.service
EOF

if ! rpm -qi firewalld ; then
    yum install -y firewalld

    if ! systemctl is-active --quiet firewalld; then
        systemctl enable firewalld
        systemctl start firewalld
    fi
fi

lineinfile "^CleanupOnExit=" "CleanupOnExit=no" "/etc/firewalld/firewalld.conf"
