#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

mkdir -p /etc/pharos/pki/etcd

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
                    "server auth",
                    "client auth"
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
        "algo": "rsa",
        "size": 2048
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

cd /etc/pharos/pki/etcd

if [ ! -e ./server.pem ]; then
    echo "Generating etcd server certificates ..."
    /opt/pharos/bin/cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=server ../config.json | /opt/pharos/bin/cfssljson -bare server
fi

echo "Checking peer certificate..."
if [ ! -e ./peer.pem ]; then
    echo "Generating etcd peer certificates ..."
    /opt/pharos/bin/cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=peer ../config.json | /opt/pharos/bin/cfssljson -bare peer
fi

if [ ! -e ./client.pem ]; then
    echo "Generating etcd client certificates ..."
    /opt/pharos/bin/cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=client ../config.json | /opt/pharos/bin/cfssljson -bare client
fi

