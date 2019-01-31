#!/bin/bash

set -ue

export PHAROS_NON_OSS=true

bundle install
gem build pharos.gemspec
gem install pharos-*.gem
pharos
pharos -v
pharos version
pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json
pharos ssh --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide
pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json
