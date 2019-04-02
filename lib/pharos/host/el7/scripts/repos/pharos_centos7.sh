#!/bin/sh

set -eu

if [ ! -e /etc/yum.repos.d/kontena-pharos.repo ]; then
    cat <<EOF >/etc/yum.repos.d/kontena-pharos.repo
[kontena-pharos]
name=kontena-pharos
baseurl=https://dl.bintray.com/kontena/pharos-rpm
gpgcheck=0
repo_gpgcheck=1
enabled=1
gpgkey=https://bintray-pk.pharos.sh?username=bintray
EOF
fi
