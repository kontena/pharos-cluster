#!/bin/bash

set -ue

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

ifconfig

envsubst < e2e/cluster.yml > cluster.yml

bundle exec bin/pharos-cluster
bundle exec bin/pharos-cluster -v
bundle exec bin/pharos-cluster version
bundle exec bin/pharos-cluster up -d -y -c cluster.yml
bundle exec bin/pharos-cluster ssh --role master -c cluster.yml -- kubectl get nodes

while ! kubectl get nodes | grep " Ready "; do
    echo "waiting for node to be ready ..."
    sleep 5
done

bundle exec bin/pharos-cluster up -d -y -c cluster.yml
bundle exec bin/pharos-cluster reset -d -y -c cluster.yml
