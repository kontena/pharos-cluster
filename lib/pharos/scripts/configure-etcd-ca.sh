#!/bin/bash

set -e

mkdir -p /etc/pharos/pki/etcd
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
    cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
fi

