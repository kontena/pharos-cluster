#!/bin/bash

set -ue

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

ifconfig

bundle install
bundle exec bin/pharos-cluster
bundle exec bin/pharos-cluster -v
bundle exec bin/pharos-cluster version
bundle exec bin/pharos-cluster up -d -y -c e2e/cluster.yml
bundle exec bin/pharos-cluster ssh --role master -c e2e/cluster.yml -- kubectl get nodes
bundle exec bin/pharos-cluster reset -d -y -c e2e/cluster.yml