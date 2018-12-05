#!/bin/bash

set -ue

export PHAROS_NON_OSS=true

bundle install
gem build pharos-cluster.gemspec
gem install pharos-cluster*.gem
pharos-cluster
pharos-cluster -v
pharos-cluster version
pharos-cluster up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json
pharos-cluster ssh --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide
pharos-cluster up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json