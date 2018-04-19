#!/bin/bash

set -eu

mkdir -p /etc/kubernetes/manifests
cat <<EOF >/etc/kubernetes/manifests/pharos-proxy.yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
  labels:
    component: pharos-proxy
    tier: worker
  name: pharos-proxy
  namespace: kube-system
spec:
  containers:
    - image: docker.io/kontena/pharos-kubelet-proxy-${ARCH}:0.3.5
      name: proxy
      env:
      - name: KUBE_MASTERS
        value: "${MASTER_HOSTS}"
  hostNetwork: true
EOF

if [ ! -e /etc/kubernetes/kubelet.conf ]; then
    mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF >/etc/systemd/system/kubelet.service.d/5-pharos-kubelet-proxy.conf
[Service]
ExecStartPre=-/sbin/swapoff -a
ExecStart=
ExecStart=/usr/bin/kubelet --pod-manifest-path=/etc/kubernetes/manifests/ --read-only-port=0 --cadvisor-port=0 --address=127.0.0.1
EOF

    export DEBIAN_FRONTEND=noninteractive
    apt-mark unhold kubelet
    apt-get install -y kubelet=${KUBE_VERSION}-00
    apt-mark hold kubelet
fi

echo "Waiting kubelet-proxy to launch on port 6443..."

while ! nc -z 127.0.0.1 6443; do
  sleep 1
done

echo "kubelet-proxy launched"