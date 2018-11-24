#!/bin/bash

set -ue

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

bundle install
bundle exec bin/pharos-cluster
bundle exec bin/pharos-cluster -v
bundle exec bin/pharos-cluster version
bundle exec bin/pharos-cluster -d -y -c e2e/cluster.yml