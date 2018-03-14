#!/bin/sh

set -ex

if [ ! -e /etc/apt/sources.list.d/docker.list ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/docker.list
deb https://download.docker.com/linux/ubuntu xenial stable
EOF
fi