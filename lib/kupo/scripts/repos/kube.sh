#!/bin/sh

set -eu

if [ ! -e /etc/apt/sources.list.d/pharos-kubernetes.list ]; then
    curl -fsSL https://bintray.com/user/downloadSubjectPublicKey?username=bintray | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/pharos-kubernetes.list
deb https://dl.bintray.com/kontena/pharos-debian xenial main
EOF
fi