#!/bin/bash

set -e

. /usr/local/share/pharos/util.sh

cat <<"EOF" >/usr/local/share/pharos/el7.sh
yum_install_with_lock() {
    versionlock="/etc/yum/pluginconf.d/versionlock.list"
    package=$1
    version=$2
    linefromfile "^0:${package}-" $versionlock
    yum install -y "${package}-${version}"
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

env_file="/etc/environment"

lineinfile "^LC_ALL=" "LC_ALL=en_US.utf-8" $env_file
lineinfile "^LANG=" "LANG=en_US.utf-8" $env_file

if ! grep -q "/usr/local/bin" $env_file ; then
    echo "PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin" >> $env_file
fi

if [ ! -z "${HTTP_PROXY}" ]; then
    lineinfile "^http_proxy=" "http_proxy=${HTTP_PROXY}" $env_file
    lineinfile "^HTTP_PROXY=" "HTTP_PROXY=${HTTP_PROXY}" $env_file
    lineinfile "^HTTPS_PROXY=" "HTTPS_PROXY=${HTTP_PROXY}" $env_file
else
    linefromfile "^http_proxy=" $env_file
    linefromfile "^HTTP_PROXY=" $env_file
    linefromfile "^HTTPS_PROXY=" $env_file
fi

if [ ! -z "${NO_PROXY}" ]; then
    lineinfile "^NO_PROXY=" "NO_PROXY=\"${NO_PROXY}\"" "$env_file"
else
    linefromfile "^NO_PROXY=" "$env_file"
fi

if [ ! "$(getenforce)" = "Disabled" ]; then
    setenforce 0 || true
    lineinfile "^SELINUX=" "SELINUX=permissive" "/etc/selinux/config"
fi

if systemctl is-active --quiet firewalld; then
    systemctl stop firewalld
    systemctl disable firewalld
fi
