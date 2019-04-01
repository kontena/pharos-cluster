#!/bin/sh

set -eu

if [ "$UNSET_PROXY" = "true" ]; then
  while read var; do unset $var; done < <(env | grep -i _proxy | sed 's/=.*//g')
fi

kubeadm init --ignore-preflight-errors all --skip-token-print --config "${CONFIG}"
