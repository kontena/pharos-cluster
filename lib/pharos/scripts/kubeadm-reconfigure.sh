#!/bin/sh

set -eu

unset http_proxy HTTP_PROXY HTTPS_PROXY

kubeadm alpha phase certs apiserver --config "${CONFIG}"
kubeadm alpha phase controlplane all --config "${CONFIG}"
kubeadm alpha phase mark-master --config "${CONFIG}"
