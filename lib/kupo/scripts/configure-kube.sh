#!/bin/bash

set -e

if [ "$(kubelet --version)" = "Kubernetes v$KUBE_VERSION" ]; then
    exit 0
fi

cat <<"EOF" >/etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Put in the basic kubelet config, later kubeadm commands will make things work properly
mkdir -p /etc/systemd/system/kubelet.service.d/
cat <<"EOF" >/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=Webhook --client-ca-file=/etc/kubernetes/pki/ca.crt"
Environment="KUBELET_CADVISOR_ARGS=--cadvisor-port=0"
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki"
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_SYSTEM_PODS_ARGS $KUBELET_NETWORK_ARGS $KUBELET_DNS_ARGS $KUBELET_AUTHZ_ARGS $KUBELET_CADVISOR_ARGS $KUBELET_CERTIFICATE_ARGS $KUBELET_EXTRA_ARGS
EOF

cd /usr/bin
curl -sSL https://dl.bintray.com/kontena/kupo/kube/${KUBE_VERSION}/bundle-${ARCH}.tar.gz | tar zx
chmod +x kube*

mkdir -p /opt/cni/bin
cd /opt/cni/bin
curl -sSL https://dl.bintray.com/kontena/kupo/cni-plugins/cni-plugins-${ARCH}-v0.7.0.tgz | tar zx

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

