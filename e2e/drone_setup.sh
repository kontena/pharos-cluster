#!/bin/bash

set -ue

if [[ $DRONE_COMMIT_MESSAGE != *"[cluster-e2e]"* ]]; then
    echo "Commit message does not contain [cluster-e2e], skipping."
    exit 0
fi

cd e2e/digitalocean
terraform init

WORKER_UP_COUNT=${WORKER_UP_COUNT:-0}

until terraform apply -auto-approve -var "cluster_name=${DRONE_BUILD_NUMBER}-do" -var "image=$1" -var "worker_up_count=${WORKER_UP_COUNT}"
do
  echo "Apply failed... trying again in 5s"
  sleep 5
done

terraform output -json > tf.json

if [ "${WORKER_UP_COUNT}" -gt "0" ]; then
  jq ".worker_up.value.address[0]" tf.json | sed 's/"//g' > worker_up_address.txt
  jq ".pharos_hosts.value.masters[0].address[0]" tf.json | sed 's/"//g' > master_address.txt
fi

echo "Downloading kubectl ..."
curl -sLO https://storage.googleapis.com/kubernetes-release/release/v1.13.5/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv kubectl /usr/local/bin/

gem build pharos-cluster.gemspec
gem install pharos-cluster*.gem

sleep 10
