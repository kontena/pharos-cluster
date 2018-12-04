#!/bin/sh

set -e

cd e2e/digitalocean
terraform init
terraform apply -auto-approve -var "cluster_name=${DRONE_BUILD_NUMBER}-do" && terraform output -json > tf.json