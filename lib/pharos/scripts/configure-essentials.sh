#!/bin/bash

set -e

if [ -n "${HTTP_PROXY}" ]; then
    cat <<EOF >/etc/environment
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
http_proxy="${HTTP_PROXY}"
HTTP_PROXY="${HTTP_PROXY}"
HTTPS_PROXY="${HTTP_PROXY}"
EOF
fi

if ! dpkg -l apt-transport-https software-properties-common > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y apt-transport-https software-properties-common
fi

cat <<EOF >/etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "0";
EOF