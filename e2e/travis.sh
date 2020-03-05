#!/bin/bash
# shellcheck disable=SC2039 disable=SC1091

set -ue

source ./e2e/util.sh

if [ "${CONTAINER_RUNTIME}" != "docker" ]; then
    echo "Stopping docker ..."
    sudo systemctl stop docker
    sudo systemctl disable docker
    sudo apt-get remove --purge docker-ce
    sudo rm -f /var/run/docker.sock
fi

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

ifconfig

envsubst < e2e/cluster.yml > cluster.yml

bundle exec bin/pharos
bundle exec bin/pharos -v
bundle exec bin/pharos version
bundle exec bin/pharos up -y -c cluster.yml
bundle exec bin/pharos ssh --role master -c cluster.yml -- kubectl get nodes
bundle exec bin/pharos kubeconfig -c cluster.yml > kubeconfig.e2e

# Verify that workloads start running
curl -sLO https://storage.googleapis.com/kubernetes-release/release/v1.17.3/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv kubectl /usr/local/bin/
export KUBECONFIG=./kubeconfig.e2e

echo "Checking that metrics-server is running:"
(retry 30 pods_running "k8s-app=metrics-server" "kube-system") || exit $?

# Test re-up
bundle exec bin/pharos up -y -c cluster.yml
# Test reset
bundle exec bin/pharos reset -d -y -c cluster.yml
