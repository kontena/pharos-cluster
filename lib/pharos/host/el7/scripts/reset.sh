#!/bin/sh

rm -rf /etc/kubernetes/manifests
sleep 5
systemctl stop kubelet
systemctl disable kubelet

if which docker ; then
    docker rm -fv $(docker ps -a -q)
    systemctl stop docker
    systemctl disable docker
elif which crictl ; then
    systemctl stop crio
    systemctl disable crio
    crictl rm $(crictl ps -a -q)
fi

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