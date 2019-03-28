#!/bin/bash

set -e

if ! systemctl is-active --quiet firewalld; then
    systemctl enable firewalld
    systemctl start firewalld
fi

# reload only if this is first run
if ! firewall-cmd --info-service pharos-worker > /dev/null 2>&1 ; then
    flock -w 5 /var/run/xtables.lock firewall-cmd --reload
    sleep 10
fi

if [ "$ROLE" = "master" ]; then
    firewall-cmd --permanent --add-service pharos-master
fi
if ! firewall-cmd --info-service pharos-worker > /dev/null 2>&1 ; then
    firewall-cmd --permanent --add-service pharos-worker
fi
if ! firewall-cmd --info-ipset pharos > /dev/null 2>&1 ; then
    firewall-cmd --permanent --add-source ipset:pharos --zone trusted
fi
if ! firewall-cmd --query-masquerade > /dev/null 2>&1 ; then
    firewall-cmd --add-masquerade --permanent
fi

flock -w 5 /var/run/xtables.lock firewall-cmd --reload
