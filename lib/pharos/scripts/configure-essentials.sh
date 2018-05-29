#!/bin/bash

set -e

. /usr/local/share/pharos/util.sh

env_file="/etc/environment"

if [ "${SET_HTTP_PROXY}" = "true" ]; then
    lineinfile "^http_proxy=" "http_proxy=${HTTP_PROXY}" $env_file
    lineinfile "^HTTP_PROXY=" "HTTP_PROXY=${HTTP_PROXY}" $env_file
    lineinfile "^HTTPS_PROXY=" "HTTPS_PROXY=${HTTP_PROXY}" $env_file
else
    linefromfile "^http_proxy=" $env_file
    linefromfile "^HTTP_PROXY=" $env_file
    linefromfile "^HTTPS_PROXY=" $env_file
fi

if ! dpkg -l apt-transport-https software-properties-common > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y apt-transport-https software-properties-common
fi

autoupgrade_file="/etc/apt/apt.conf.d/20auto-upgrades"
lineinfile "^APT::Periodic::Update-Package-Lists " 'APT::Periodic::Update-Package-Lists "1";' $autoupgrade_file
lineinfile "^APT::Periodic::Unattended-Upgrade " 'APT::Periodic::Unattended-Upgrade "0";' $autoupgrade_file