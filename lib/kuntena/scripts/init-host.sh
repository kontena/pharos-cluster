#!/bin/bash

set -e

modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
sysctl -p

mkdir -p /etc/docker
cat <<EOF >/etc/docker/daemon.json
{
    "storage-driver": "overlay2",
    "iptables": false,
    "ip-masq": false,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    }
}
EOF

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/docker.list
deb https://download.docker.com/linux/ubuntu xenial stable
EOF

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y ntp docker-ce=17.03.2~ce-0~ubuntu-xenial kubelet=1.9.3-00 kubeadm=1.9.3-00 kubectl=1.9.3-00
usermod -aG docker ubuntu