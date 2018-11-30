#!/bin/sh

set -eu

(env | cut -d"=" -f1|grep -i -- "_proxy$") | while read -r var; do unset "$var"; done

kubeadm init --ignore-preflight-errors all --skip-token-print --config "${CONFIG}"

