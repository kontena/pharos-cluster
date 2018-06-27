#!/bin/sh

rm -rf /etc/kubernetes/manifests
sleep 5
systemctl stop kubelet
systemctl disable kubelet

if systemctl is-active --quiet docker ; then
    docker rm -fv $(docker ps -a -q)
    systemctl stop docker
    systemctl disable docker
fi

if systemctl is-active --quiet crio ; then
    crictl stopp $(crictl pods -q)
    crictl rmp $(crictl pods -q)
    systemctl stop crio
    systemctl disable crio
fi

kubeadm reset

yum remove -y kubeadm kubelet kubectl docker

sudo rm -rf /etc/kubernetes \
    /etc/pharos \
    /etc/crio \
    /etc/systemd/system/kubelet.service \
    /etc/systemd/system/kubelet.service.d \
    /etc/systemd/system/crio.service \
    ~/.kube \
    /var/lib/docker \
    /var/lib/containerd \
    /var/lib/containers \
    /var/lib/kubelet \
    /opt/cni \
    /var/lib/etcd \
    /var/lib/weave \
    /var/lib/calico \
    /usr/local/bin/crio \
    /usr/local/bin/crio-config \
    /usr/local/bin/conmon \
    /usr/local/lib/cri-o-runc \
    /usr/local/bin/crio \
    /usr/local/bin/skopeo \
    /usr/local/bin/runc \
    /usr/local/bin/crictl

systemctl daemon-reload
systemctl reset-failed