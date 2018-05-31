#!/bin/sh

set -eu

unset http_proxy HTTP_PROXY HTTPS_PROXY

kubeadm alpha phase controlplane all --config ${TMP_FILE}
kubeadm alpha phase mark-master --config ${TMP_FILE}