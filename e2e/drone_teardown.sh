#!/bin/sh

set -e

cd e2e/digitalocean
until terraform destroy -auto-approve
do
  echo "Destroy failed... trying again in 5s"
  sleep 5
done