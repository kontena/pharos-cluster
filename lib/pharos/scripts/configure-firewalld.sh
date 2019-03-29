#!/bin/bash

set -e

RELOAD="false"
# reload only if this is first run
if ! firewall-cmd --get-services | grep pharos-worker > /dev/null 2>&1 ; then
    RELOAD="true"
    firewall-cmd --reload
    sleep 10
fi

if [ "$ROLE" = "master" ]; then
    firewall-cmd --permanent --add-service pharos-master
fi

firewall-cmd --permanent --add-service pharos-worker
firewall-cmd --permanent --add-source ipset:pharos --zone trusted
firewall-cmd --add-masquerade --permanent

if [[ "${RELOAD}" = "true" ]]; then
    firewall-cmd --reload
    sleep 10
fi
