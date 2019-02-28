#!/bin/sh

set -e

cd e2e/digitalocean

if [ ! -f terraform.tfstate ]
then
    echo "TF state not found, not running teardown"
    exit 0
fi

until terraform destroy -auto-approve
do
  echo "Destroy failed... trying again in 5s"
  sleep 5
done