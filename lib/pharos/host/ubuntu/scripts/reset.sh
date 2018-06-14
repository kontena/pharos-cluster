#!/bin/sh

systemctl stop kubelet
systemctl disable kubelet
systemctl stop docker
systemctl disable docker
kubeadm reset
apt-get purge -y --allow-change-held-packages --purge kubeadm kubelet kubectl docker.io cri-o-${CRIO_VERSION}
apt-get autoremove -y
rm -rf /etc/kubernetes \
    /etc/pharos \
    /etc/systemd/system/kubelet.service \
    /etc/systemd/system/kubelet.service.d \
    ~/.kube \
    /var/lib/docker \
    /var/lib/containerd \
    /var/lib/kubelet \
    /opt/cni \
    /var/lib/etcd \
    /var/lib/weave \
    /var/lib/calico \
    /usr/local/bin/crictl

systemctl daemon-reload
systemctl reset-failed