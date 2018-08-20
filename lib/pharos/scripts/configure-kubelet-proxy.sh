#!/bin/bash

set -eu

mkdir -p /etc/kubernetes/manifests
mkdir -p /etc/kubernetes/tmp
cat >/etc/kubernetes/tmp/pharos-proxy.yaml <<EOF && mv /etc/kubernetes/tmp/pharos-proxy.yaml /etc/kubernetes/manifests/pharos-proxy.yaml
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
    - image: ${IMAGE_REPO}/pharos-kubelet-proxy-${ARCH}:${VERSION}
      name: proxy
      env:
      - name: KUBE_MASTERS
        value: "${MASTER_HOSTS}"
  hostNetwork: true
EOF
