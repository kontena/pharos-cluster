#!/bin/bash
# shellcheck disable=SC2039 disable=SC1091

set -u

if [ ! -f e2e/digitalocean/tf.json ]
then
    echo "TF output not found, skipping."
    exit 0
fi

source ./e2e/util.sh

export KUBECONFIG=./kubeconfig.e2e
export PHAROS_NON_OSS=true

# Test cluster bootstrapping
timeout 700 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?
(pharos kubeconfig -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json > kubeconfig.e2e) || exit $?
(pharos exec --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide) || exit $?

# Verify that workloads start running

echo "Checking that ingress-nginx is running:"
(retry 30 pods_running "app=ingress-nginx" "ingress-nginx") || exit $?

echo "Checking that kontena-lens is running:"
(retry 30 pods_running "app=dashboard" "kontena-lens") || exit $?
