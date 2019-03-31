#!/bin/sh

set -eu

if [ ! -e /etc/apt/sources.list.d/pharos-kubernetes.list ]; then
    curl -fsSL https://bintray-pk.pharos.sh/?username=bintray | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/pharos-kubernetes.list
deb http://dl.bintray.com/kontena/pharos-debian bionic main
EOF
fi
