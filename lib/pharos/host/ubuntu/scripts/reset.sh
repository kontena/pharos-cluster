#!/bin/sh

rm -rf /etc/kubernetes/manifests
sleep 5
systemctl stop kubelet
systemctl disable kubelet

if which docker ; then
    docker rm -fv $(docker ps -a -q)
    systemctl stop docker
    systemctl disable docker
elif which crio ; then
    crictl rm $(crictl ps -a -q)
    systemctl stop crio
    systemctl disable crio
fi

kubeadm reset

apt-get purge -y --allow-change-held-packages --purge kubeadm kubelet kubectl docker.io
apt-get autoremove -y
rm -rf /etc/kubernetes \
    /etc/pharos \
    /etc/crio \
    /etc/systemd/system/kubelet.service \
    /etc/systemd/system/kubelet.service.d \
    /etc/systemd/system/crio.service \ \
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