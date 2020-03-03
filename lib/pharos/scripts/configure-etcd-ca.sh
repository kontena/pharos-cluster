#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

mkdir -p /etc/pharos/pki
if [ ! -e /etc/pharos/pki/ca-csr.json ]; then
    cat <<EOF >/etc/pharos/pki/ca-csr.json
{
    "CN": "Kontena Pharos CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "L": "NY",
            "O": "Kontena Inc",
            "ST": "New York",
            "OU": "Kontena Pharos"
        }
    ]
}
EOF
fi

cd /etc/pharos/pki

if [ ! -e ca.pem ]; then
    echo "Initializing Certificate Authority ..."
    /opt/pharos/bin/cfssl gencert -initca ca-csr.json | /opt/pharos/bin/cfssljson -bare ca -
fi

