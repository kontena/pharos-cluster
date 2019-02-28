#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

if ! dpkg -l apt-transport-https software-properties-common curl > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y apt-transport-https software-properties-common curl
fi

if ! dpkg -l firewalld > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y firewalld ipset
fi

autoupgrade_file="/etc/apt/apt.conf.d/20auto-upgrades"
if [ ! -f "$autoupgrade_file" ]; then
    touch "$autoupgrade_file"
fi
lineinfile "^APT::Periodic::Update-Package-Lists " 'APT::Periodic::Update-Package-Lists "1";' "$autoupgrade_file"
lineinfile "^APT::Periodic::Unattended-Upgrade " 'APT::Periodic::Unattended-Upgrade "0";' "$autoupgrade_file"
