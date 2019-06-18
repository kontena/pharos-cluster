#!/bin/bash

set -ue

if [[ $DRONE_COMMIT_MESSAGE != *"[cluster-e2e]"* ]]; then
    echo "Commit message does not contain [cluster-e2e], skipping."
    exit 0
fi

cd e2e/digitalocean
terraform init

WORKER_UP=${WORKER_UP:-false}
if [ "${WORKER_UP}" = "true" ]; then
  WORKER_UP_COUNT="1"
else
  WORKER_UP_COUNT="0"
fi

until terraform apply -auto-approve -var "cluster_name=${DRONE_BUILD_NUMBER}-do" -var "image=$1" -var "worker_up_count=${WORKER_UP_COUNT}"
do
  echo "Apply failed... trying again in 5s"
  sleep 5
done

terraform output -json > tf.json

if [ "${WORKER_UP}" = "true" ]; then
  jq ".worker_up.value.address[0]" tf.json | sed 's/"//g' > worker_up_address.txt
  jq ".pharos_hosts.value.masters[0].address[0]" tf.json | sed 's/"//g' > master_address.txt
fi

sleep 10
