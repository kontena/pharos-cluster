#!/bin/bash

set -e

if [ -e /etc/kubernetes/manifests/pharos-etcd.yaml ]; then
  exit
fi

mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF >/etc/systemd/system/kubelet.service.d/5-pharos-etcd.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --pod-manifest-path=/etc/kubernetes/manifests/ --read-only-port=0 --cadvisor-port=0
EOF

apt-mark unhold kubelet
apt-get install -y kubelet=${KUBE_VERSION}-00
apt-mark hold kubelet

mkdir -p /etc/kubernetes/manifests
cat <<EOF >/etc/kubernetes/manifests/pharos-etcd.yaml
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
    - --listen-client-urls=https://${PEER_IP}:2379
    - --advertise-client-urls=https://${PEER_IP}:2379
    - --listen-peer-urls=https://${PEER_IP}:2380
    - --initial-advertise-peer-urls=https://${PEER_IP}:2380
    - --client-cert-auth=true
    - --peer-client-cert-auth=true
    - --initial-cluster=${INITIAL_CLUSTER}
    - --initial-cluster-token=pharos-etcd-token
    - --initial-cluster-state=new

    image: k8s.gcr.io/etcd-amd64:${ETCD_VERSION}
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
systemctl daemon-reload
systemctl restart kubelet

echo "Waiting etcd to launch on port 2380..."

while ! nc -z ${PEER_IP} 2380; do
  sleep 1
done

echo "etcd launched"