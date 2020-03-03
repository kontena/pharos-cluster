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

kubeadm reset --force

export DEBIAN_FRONTEND=noninteractive
apt-get purge -y --allow-change-held-packages --purge kubeadm kubelet kubectl kubernetes-cni docker.io
apt-get autoremove -y
rm -rf /etc/kubernetes \
    /etc/pharos \
    /etc/systemd/system/kubelet.service \
    /etc/systemd/system/kubelet.service.d \
    ~/.kube \
    /var/lib/kubelet \
    /var/lib/containers \
    /opt/cni \
    /var/lib/etcd \
    /var/lib/weave \
    /var/lib/calico \
    /usr/local/bin/crictl \
    /opt/pharos \
    /usr/local/bin/pharos-kubeadm-*

systemctl daemon-reload
systemctl reset-failed
