#!/bin/sh

set -e

echo "Waiting kubelet-proxy to launch on port 6443..."

while ! nc -z 127.0.0.1 6443; do
  sleep 1
done

echo "kubelet-proxy launched"