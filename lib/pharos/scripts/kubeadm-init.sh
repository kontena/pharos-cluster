#!/bin/sh

set -eu

unset http_proxy HTTP_PROXY HTTPS_PROXY

kubeadm init --ignore-preflight-errors all --skip-token-print --config ${TMP_FILE}