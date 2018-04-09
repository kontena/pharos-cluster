#!/bin/bash

set -e

mkdir -p /etc/pharos/pki/etcd


if [ ! -e  /usr/local/bin/cfssl ]; then
    curl -s -L -o /usr/local/bin/cfssl \
        https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
    chmod +x /usr/local/bin/cfssl
fi
if [ ! -e  /usr/local/bin/cfssljson ]; then
    curl -s -L -o /usr/local/bin/cfssljson \
        https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
    chmod +x /usr/local/bin/cfssljson
fi

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

if [ ! -e /etc/pharos/pki/ca-config.json ]; then
    cat <<EOF >/etc/pharos/pki/ca-config.json
{
    "signing": {
        "default": {
            "expiry": "43800h"
        },
        "profiles": {
            "server": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF
fi

if [ ! -e /etc/pharos/pki/config.json ]; then
    cat <<EOF >/etc/pharos/pki/config.json
{
    "CN": "${PEER_IP}",
    "hosts": [
        "localhost",
        "${PEER_IP}"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "NY",
            "ST": "New York"
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

cd /etc/pharos/pki/etcd

if [ ! -e server.pem ]; then
    echo "Generating etcd client certificates ..."
    cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=server ../config.json | cfssljson -bare server
fi

if [ ! -e peer.pem ]; then
    echo "Generating etcd peer certificates ..."
    cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=peer ../config.json | cfssljson -bare peer
fi

if [ ! -e client.pem ]; then
    echo "Generating etcd client certificates ..."
    cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=client ../config.json | cfssljson -bare client
fi

