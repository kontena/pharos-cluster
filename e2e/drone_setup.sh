#!/bin/sh

set -e

cd e2e/digitalocean
terraform init
until terraform apply -auto-approve -var "cluster_name=${DRONE_BUILD_NUMBER}-do"
do
  echo "Apply failed... trying again in 5s"
  sleep 5
done
terraform output -json > tf.json

sleep 10