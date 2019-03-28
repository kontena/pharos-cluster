#!/bin/bash
# shellcheck disable=SC2039 disable=SC1091

set -u

source ./e2e/util.sh

export PHAROS_NON_OSS=true

gem build pharos-cluster.gemspec
gem install pharos-cluster*.gem
# Test that we can actually load everything
pharos || exit $?
pharos -v || exit $?
pharos version || exit $?
# Smoke the license commands
pharos license assign --help || exit $?
pharos license inspect --help || exit $?

# Test cluster bootstrapping
timeout 600 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?
(pharos kubeconfig -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json > kubeconfig.e2e) || exit $?
(pharos exec --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide) || exit $?

# Verify that workloads start running
curl -sLO https://storage.googleapis.com/kubernetes-release/release/v1.13.4/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv kubectl /usr/local/bin/
export KUBECONFIG=./kubeconfig.e2e

(retry 30 pods_running "app=ingress-nginx" "ingress-nginx") || exit $?
(retry 30 pods_running "app=dashboard" "kontena-lens") || exit $?

# Rerun up to confirm that non-initial run goes through
timeout 300 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?
