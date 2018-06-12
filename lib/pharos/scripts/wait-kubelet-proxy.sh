#!/bin/sh

set -e

echo "Waiting kubelet-proxy to launch on port 6443..."

while ! ( bash -c 'echo > /dev/tcp/localhost/6443') >/dev/null 2>&1; do
  sleep 1;
done

echo "kubelet-proxy launched"