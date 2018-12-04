#!/bin/bash

set -ue

export PHAROS_NON_OSS=true

bundle install
bundle exec bin/pharos-cluster
bundle exec bin/pharos-cluster -v
bundle exec bin/pharos-cluster version
bundle exec bin/pharos-cluster up -d -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json
bundle exec bin/pharos-cluster ssh --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide
bundle exec bin/pharos-cluster up -d -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json
bundle exec bin/pharos-cluster reset -d -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json