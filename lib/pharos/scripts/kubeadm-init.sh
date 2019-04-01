#!/bin/bash

set -eu

if [ "$UNSET_PROXY" = "true" ]; then
  (env | cut -d"=" -f1|grep -i -- "_proxy$") | while read -r var; do unset "$var"; done
fi

kubeadm init --ignore-preflight-errors all --skip-token-print --config "${CONFIG}"
