#!/bin/bash

set -e

# shellcheck disable=SC1091
. /usr/local/share/pharos/util.sh

cat <<"EOF" >/usr/local/share/pharos/el7.sh
yum_install_with_lock() {
    versionlock="/etc/yum/pluginconf.d/versionlock.list"
    package=$1
    version=$2
    linefromfile "^0:${package}-" $versionlock
    yum install -y "${package}-${version}"
    if ! rpm -qi "${package}-${version}" > /dev/null ; then
        yum downgrade -y "${package}-${version}"
    fi
    lineinfile "^0:${package}-" "0:${package}-${version}-0.*" $versionlock
}
EOF
chmod +x /usr/local/share/pharos/el7.sh

if ! rpm -qi yum-plugin-versionlock ; then
    yum install -y yum-plugin-versionlock
fi

if ! rpm -qi chrony ; then
    yum install -y chrony
    systemctl enable chronyd
    systemctl start chronyd
fi

if ! rpm -qi conntrack-tools ; then
    yum install -y conntrack-tools
fi

if ! rpm -qi iscsi-initiator-utils ; then
    yum install -y iscsi-initiator-utils
fi

if ! rpm -qi yum-utils ; then
    yum install -y yum-utils
fi

env_file="/etc/environment"

lineinfile "^LC_ALL=" "LC_ALL=en_US.utf-8" "$env_file"
lineinfile "^LANG=" "LANG=en_US.utf-8" "$env_file"

if [[ $PATH != *local/bin* ]] || [[ $PATH != *usr/sbin* ]]; then
  PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
  lineinfile "^PATH=" "PATH=$PATH" "$env_file"
fi

if ! (getenforce | grep -q "Disabled"); then
    setenforce 0 || true
    lineinfile "^SELINUX=" "SELINUX=permissive" "/etc/selinux/config"
fi
