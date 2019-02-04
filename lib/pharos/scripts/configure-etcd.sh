#!/bin/bash

set -e

etcd_version_matches() {
  grep -q "etcd:${ETCD_VERSION}" /etc/kubernetes/manifests/pharos-etcd.yaml
}

mkdir -p /etc/kubernetes/manifests
mkdir -p /etc/kubernetes/tmp
if [ ! -e /etc/kubernetes/manifests/pharos-etcd.yaml ] || ! etcd_version_matches; then
  mkdir -p /var/lib/etcd
  chmod 700 /var/lib/etcd

  cat  >/etc/kubernetes/tmp/pharos-etcd.yaml <<EOF && install -m 0644 /etc/kubernetes/tmp/pharos-etcd.yaml /etc/kubernetes/manifests/pharos-etcd.yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
  labels:
    component: etcd
    tier: control-plane
  name: etcd
  namespace: kube-system
spec:
  priorityClassName: system-node-critical
  containers:
  - command:
    - etcd
    - --name=${PEER_NAME}
    - --cert-file=/etc/kubernetes/pki/etcd/server.pem
    - --key-file=/etc/kubernetes/pki/etcd/server-key.pem
    - --trusted-ca-file=/etc/kubernetes/pki/ca.pem
    - --peer-trusted-ca-file=/etc/kubernetes/pki/ca.pem
    - --data-dir=/var/lib/etcd
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.pem
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer-key.pem
    - --listen-client-urls=https://localhost:2379,https://${PEER_IP}:2379
    - --advertise-client-urls=https://${PEER_IP}:2379
    - --listen-peer-urls=https://${PEER_IP}:2380
    - --initial-advertise-peer-urls=https://${PEER_IP}:2380
    - --client-cert-auth=true
    - --peer-client-cert-auth=true
    - --initial-cluster=${INITIAL_CLUSTER}
    - --initial-cluster-token=pharos-etcd-token
    - --initial-cluster-state=${INITIAL_CLUSTER_STATE}

    image: ${IMAGE_REPO}/etcd:${ETCD_VERSION}
    livenessProbe:
      exec:
        command:
        - /bin/sh
        - -ec
        - ETCDCTL_API=3 etcdctl --endpoints=localhost:2379 --cacert=/etc/kubernetes/pki/ca.pem
          --cert=/etc/kubernetes/pki/etcd/client.pem --key=/etc/kubernetes/pki/etcd/client-key.pem
          get foo
      failureThreshold: 8
      initialDelaySeconds: 15
      timeoutSeconds: 15
    name: etcd
    volumeMounts:
    - mountPath: /var/lib/etcd
      name: etcd-data
    - mountPath: /etc/kubernetes/pki
      name: etcd-certs
  hostNetwork: true
  volumes:
  - hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
  - hostPath:
      path: /etc/pharos/pki
      type: DirectoryOrCreate
    name: etcd-certs
EOF
fi
