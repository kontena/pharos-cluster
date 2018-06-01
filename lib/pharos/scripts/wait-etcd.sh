#!/bin/bash

set -e

etcd_healthy() {
  response=$(curl -s --noproxy "*" --cacert /etc/pharos/pki/ca.pem --cert /etc/pharos/pki/etcd/client.pem --key /etc/pharos/pki/etcd/client-key.pem https://${PEER_IP}:2379/health)
  [ "${response}" = '{"health": "true"}' ]
}

echo "Waiting etcd to launch on port 2380..."
while ! etcd_healthy; do
  sleep 1
done
echo "etcd launched"