#!/bin/sh

set -eu

if [ "$UNSET_PROXY" = "true" ]; then
  while read var; do unset $var; done < <(env | grep -i _proxy | sed 's/=.*//g')
fi

kubeadm init phase control-plane all --config "${CONFIG}"
kubeadm init phase mark-control-plane --config "${CONFIG}"
kubeadm init phase upload-config all --config "${CONFIG}"
