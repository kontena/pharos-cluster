#!/bin/bash

set -ue

if [[ $DRONE_COMMIT_MESSAGE != *"[cluster-e2e]"* ]]; then
    echo "Commit message does not contain [cluster-e2e], skipping."
    exit 0
fi

cd e2e/digitalocean
terraform init
until terraform apply -auto-approve -var "cluster_name=${DRONE_BUILD_NUMBER}-do" -var "image=$1"
do
  echo "Apply failed... trying again in 5s"
  sleep 5
done
terraform output -json > tf.json.tmp

jq 'del(.pharos_hosts.value.worker_up)' tf.json.tmp > tf.json
cat tf.json

if [ "$1" = "ubuntu-18-04-x64" ]; then
  jq '.pharos_hosts.value.worker_up[0]' tf.json.tmp > worker.json
fi

rm -f tf.json.tmp

sleep 10
