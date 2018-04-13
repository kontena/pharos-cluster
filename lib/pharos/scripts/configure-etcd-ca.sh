#!/bin/bash

set -e

if [ "${ARCH}" = "amd64" ]; then
    MIRROR="http://mirrors.kernel.org/ubuntu"
else
    MIRROR="http://ports.ubuntu.com"
fi

CFSSL_URL="${MIRROR}/pool/universe/g/golang-github-cloudflare-cfssl/golang-cfssl_1.2.0+git20160825.89.7fb22c8-3_${ARCH}.deb"

if [ ! -e  /usr/bin/cfssl ]; then
    curl -sL -o /tmp/cfssl.deb ${CFSSL_URL}
    dpkg -i /tmp/cfssl.deb && rm /tmp/cfssl.deb
fi

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

