#!/bin/bash

set -ue

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

ifconfig

envsubst < e2e/cluster.yml > cluster.yml

pharos-cluster
pharos-cluster -v
pharos-cluster version
pharos-cluster up -d -y -c cluster.yml
pharos-cluster ssh --role master -c cluster.yml -- kubectl get nodes
pharos-cluster up -d -y -c cluster.yml
pharos-cluster reset -d -y -c cluster.yml
