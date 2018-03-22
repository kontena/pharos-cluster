#!/bin/sh

set -eu

if [ ! -e /etc/apt/sources.list.d/kubernetes.list ]; then
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
fi
