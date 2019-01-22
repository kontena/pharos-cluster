#!/bin/bash

set -e

if ! systemctl is-active --quiet firewalld; then
    systemctl enable firewalld
    systemctl start firewalld
fi

firewall-cmd --reload
if [ "$ROLE" = "master" ]; then
    firewall-cmd --permanent --add-service pharos-master
fi
firewall-cmd --permanent --add-service pharos-worker
firewall-cmd --permanent --add-source ipset:pharos --zone trusted
firewall-cmd --add-masquerade --permanent --zone trusted
firewall-cmd --reload
