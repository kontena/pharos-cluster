#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

export DEBIAN_FRONTEND=noninteractive

if ! dpkg -l apt-transport-https software-properties-common > /dev/null; then
    apt-get update -y
    apt-get install -y apt-transport-https software-properties-common
fi

apt-get install -y libseccomp

autoupgrade_file="/etc/apt/apt.conf.d/20auto-upgrades"
if [ ! -f $autoupgrade_file ]; then
    touch $autoupgrade_file
fi
lineinfile "^APT::Periodic::Update-Package-Lists " 'APT::Periodic::Update-Package-Lists "1";' $autoupgrade_file
lineinfile "^APT::Periodic::Unattended-Upgrade " 'APT::Periodic::Unattended-Upgrade "0";' $autoupgrade_file
