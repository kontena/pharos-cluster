#!/bin/sh

set -eu

if [ "$SKIP_UNSET_PROXY" = "true" ]; then
  (env | cut -d"=" -f1|grep -i -- "_proxy$") | while read -r var; do unset "$var"; done
fi

kubeadm init phase control-plane all --config "${CONFIG}"
kubeadm init phase mark-control-plane --config "${CONFIG}"
kubeadm init phase upload-config all --config "${CONFIG}"
