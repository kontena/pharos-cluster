#!/bin/bash

set -e

if ! systemctl is-active --quiet firewalld; then
    systemctl enable firewalld
    systemctl start firewalld
fi

if ! firewall-cmd --info-service pharos-worker 2&>1 /dev/null ; then
    flock /var/run/xtables.lock -c "firewall-cmd --reload"
    sleep 10
fi

if [ "$ROLE" = "master" ]; then
    firewall-cmd --permanent --add-service pharos-master
fi
if ! firewall-cmd --info-service pharos-worker 2&>1 /dev/null ; then
    firewall-cmd --permanent --add-service pharos-worker
fi
if ! firewall-cmd --info-ipset pharos 2&>1 /dev/null ; then
    firewall-cmd --permanent --add-source ipset:pharos --zone trusted
fi
if ! firewall-cmd --query-masquerade 2&>1 /dev/null ; then
    firewall-cmd --add-masquerade --permanent
fi

flock /var/run/xtables.lock -c "firewall-cmd --reload"
