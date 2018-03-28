#!/bin/bash

set -e

mkdir -p /etc/cni/net.d/
cat <<EOF >/etc/cni/net.d/00-pharos.conflist
{
    "cniVersion": "0.3.0",
    "name": "pharos",
    "plugins": [
        {
            "name": "weave",
            "type": "weave-net",
            "hairpinMode": true
        },
        {
            "type": "portmap",
            "capabilities": {"portMappings": true},
            "snat": true
        }
    ]
}
EOF