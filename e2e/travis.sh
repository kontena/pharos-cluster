#!/bin/bash

set -ue

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

ifconfig

envsubst < e2e/cluster.yml > cluster.yml

bundle exec bin/pharos
bundle exec bin/pharos -v
bundle exec bin/pharos version
bundle exec bin/pharos up -d -y -c cluster.yml
bundle exec bin/pharos ssh --role master -c cluster.yml -- kubectl get nodes

while ! kubectl get nodes | grep " Ready "; do
    echo "waiting for node to be ready ..."
    sleep 5
done

bundle exec bin/pharos up -d -y -c cluster.yml
bundle exec bin/pharos reset -d -y -c cluster.yml
