#!/bin/sh

set -ue

cd e2e/digitalocean
terraform init
until terraform apply -auto-approve -var "cluster_name=${DRONE_BUILD_NUMBER}-do" -var "image=$1"
do
  echo "Apply failed... trying again in 5s"
  sleep 5
done
terraform output -json > tf.json

sleep 10