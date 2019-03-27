#!/bin/sh

rm -rf /etc/kubernetes/manifests
sleep 5
systemctl stop kubelet
systemctl disable kubelet

if systemctl is-active --quiet docker ; then
    # shellcheck disable=SC2046
    docker stop $(docker ps -q)
    systemctl stop docker
    systemctl disable docker
fi

if systemctl is-active --quiet crio ; then
    # shellcheck disable=SC2046
    crictl stopp $(crictl pods -q)
    systemctl stop crio
    systemctl disable crio
fi

kubeadm reset --force

export DEBIAN_FRONTEND=noninteractive
apt-get purge -y --allow-change-held-packages --purge kubeadm kubelet kubectl kubernetes-cni docker.io cri-o
apt-get autoremove -y
rm -rf /etc/kubernetes \
    /etc/pharos \
    /etc/crio \
    /etc/systemd/system/kubelet.service \
    /etc/systemd/system/kubelet.service.d \
    /etc/systemd/system/crio.service \
    ~/.kube \
    /var/lib/kubelet \
    /var/lib/containers \
    /opt/cni \
    /var/lib/etcd \
    /var/lib/weave \
    /var/lib/calico \
    /usr/local/bin/crio \
    /usr/local/bin/crio-config \
    /usr/local/bin/conmon \
    /usr/local/lib/cri-o-runc \
    /usr/local/bin/skopeo \
    /usr/local/bin/runc \
    /usr/local/bin/crictl \
    /usr/local/bin/pharos-kubeadm-*

systemctl daemon-reload
systemctl reset-failed
