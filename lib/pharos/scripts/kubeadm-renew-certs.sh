#!/bin/bash

set -eu

if [ "$UNSET_PROXY" = "true" ]; then
  while read -r var; do unset "$var"; done < <(env | grep -i _proxy | sed 's/=.*//g')
fi

kubeadm init phase certs apiserver --config "${CONFIG}"
kubeadm alpha certs renew apiserver --config "${CONFIG}"
