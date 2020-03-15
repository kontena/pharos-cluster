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

yum remove -y kubeadm kubelet kubectl kubernetes-cni docker

sudo rm -rf /etc/kubernetes \
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
    /usr/local/bin/runc \
    /usr/local/bin/crictl \
    /opt/pharos \
    /usr/local/bin/pharos-kubeadm-*

# reset versionlock
echo '' | sudo tee /etc/yum/pluginconf.d/versionlock.list

systemctl daemon-reload
systemctl reset-failed
