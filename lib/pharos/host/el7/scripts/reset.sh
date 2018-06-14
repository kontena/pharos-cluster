#!/bin/sh

systemctl stop kubelet
systemctl disable kubelet

systemctl stop docker
systemctl disable docker

kubeadm reset
yum remove -y kubeadm kubelet kubectl docker

sudo rm -rf /etc/kubernetes \
    /etc/pharos \
    /etc/kubernetes \
    /etc/systemd/system/kubelet.service \
    /etc/systemd/system/kubelet.service.d \
    /var/etcd \
    ~/.kube \
    /var/lib/docker \
    /var/lib/containerd \
    /var/lib/kubelet \
    /opt/cni \
    /var/lib/etcd \
    /var/lib/weave \
    /var/lib/calico

systemctl daemon-reload
systemctl reset-failed