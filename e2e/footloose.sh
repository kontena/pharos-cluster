#!/bin/bash

set -e

curl -Lo footloose https://github.com/weaveworks/footloose/releases/download/0.3.0/footloose-0.3.0-linux-x86_64
chmod +x footloose
sudo mv footloose /usr/local/bin/

pushd e2e/footloose
sudo swapoff -a
docker build -t footloose:bionic .
footloose create
popd

bundle exec bin/pharos up -y -c e2e/footloose/cluster.yml
