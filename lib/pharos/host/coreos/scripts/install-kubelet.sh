#!/bin/sh

set -e

REPO="https://dl.bintray.com/kontena/pharos-bin"

install_kube_pkg() {
    version=$1
    arch=$2
    name=$3

    tmpdir=$(mktemp -d)
    pushd $tmpdir
        curl -sSLO "${REPO}/kube/${version}/${name}-${arch}.gz"
        curl -sSLO "${REPO}/kube/${version}/${name}-${arch}.gz.asc"
        gpg --verify "${name}-${arch}.gz.asc" "${name}-${arch}.gz"
        gunzip ${name}-${arch}.gz
        mv ${name}-${arch} /opt/bin/${name}
        chmod +x /opt/bin/${name}
    popd
    rm -rf $tmpdir
}

# CNI
if [ ! -e /opt/cni/bin/loopback ]; then
    mkdir -p /opt/cni/bin
    curl -sSL "${REPO}/cni-plugins/cni-plugins-${ARCH}-v0.6.0.tgz" | tar -C /opt/cni/bin -xz
fi

mkdir -p /opt/bin
if ! which kubeadm > /dev/null || [ "$(kubeadm version -o short)" != "v${KUBE_VERSION}" ]; then
    install_kube_pkg ${KUBE_VERSION} ${ARCH} "kubeadm"
fi
if ! which kubectl > /dev/null || [ "$(kubectl version -o json | jq -r .clientVersion.gitVersion)" != "v${KUBE_VERSION}" ]; then
    install_kube_pkg ${KUBE_VERSION} ${ARCH} "kubectl"
fi

if [ ! -e /etc/kubernetes/kubelet.conf ]; then
    cat <<"EOF" >/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=Webhook --client-ca-file=/etc/kubernetes/pki/ca.crt"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_CADVISOR_ARGS=--cadvisor-port=0"
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true"
ExecStart=
ExecStart=/opt/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_SYSTEM_PODS_ARGS $KUBELET_NETWORK_ARGS $KUBELET_DNS_ARGS $KUBELET_AUTHZ_ARGS $KUBELET_CGROUP_ARGS $KUBELET_CADVISOR_ARGS $KUBELET_CERTIFICATE_ARGS $KUBELET_EXTRA_ARGS
EOF
cat <<EOF >/etc/systemd/system/kubelet.service.d/05-pharos.conf
Environment="KUBELET_EXTRA_ARGS=--hostname-override=${HOSTNAME} --read-only-port=0"
Environment="KUBELET_DNS_ARGS=--cluster-dns=${CLUSTER_DNS} --cluster-domain=cluster.local"
EOF
    systemctl daemon-reload
    systemctl restart kubelet
fi