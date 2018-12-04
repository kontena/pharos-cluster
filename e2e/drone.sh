#!/bin/bash

set -ue

export PHAROS_NON_OSS=true

PHAROS="bundle exec bin/pharos-cluster"

bundle install
$PHAROS
$PHAROS -v
$PHAROS version
$PHAROS up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json
$PHAROS ssh --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide
$PHAROS up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json