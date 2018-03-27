#!/bin/bash

set -e

if [ "$(kubelet --version)" = "Kubernetes v$KUBE_VERSION" ]; then
    exit 0
fi

apt-get install -y iproute2 socat util-linux mount ebtables ethtool

cat <<"EOF" >/etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/

[Service]
ExecStart=/usr/local/bin/kubelet
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
ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_SYSTEM_PODS_ARGS $KUBELET_NETWORK_ARGS $KUBELET_DNS_ARGS $KUBELET_AUTHZ_ARGS $KUBELET_CADVISOR_ARGS $KUBELET_CERTIFICATE_ARGS $KUBELET_EXTRA_ARGS
EOF

systemctl daemon-reload

if systemctl is-active --quiet kubelet ; then
    systemctl stop kubelet
fi

for bin in kubelet kubectl kubeadm
do
    curl -sSL https://dl.bintray.com/kontena/pharos-bin/kube/${KUBE_VERSION}/${bin}-${ARCH}.gz | gunzip > /usr/local/bin/${bin}
    chmod +x /usr/local/bin/${bin}
done

mkdir -p /opt/cni/bin
cd /opt/cni/bin
curl -sSL https://dl.bintray.com/kontena/pharos-bin/cni-plugins/cni-plugins-${ARCH}-v0.6.0.tgz | tar zx

if ! systemctl is-enabled --quiet kubelet ; then
    systemctl enable kubelet
fi

systemctl start kubelet
