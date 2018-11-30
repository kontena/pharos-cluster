#!/bin/sh

set -eu

(env | cut -d"=" -f1|grep -i -- "_proxy$") | while read -r var; do unset "$var"; done

kubeadm alpha phase certs apiserver --config "${CONFIG}"
kubeadm alpha phase controlplane all --config "${CONFIG}"
kubeadm alpha phase mark-master --config "${CONFIG}"

