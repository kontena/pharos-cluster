#!/bin/bash

set -e

. /usr/local/share/pharos/util.sh

if ! rpm -qi yum-plugin-versionlock ; then
    yum install -y yum-plugin-versionlock
fi

if ! rpm -qi nmap-ncat ; then
    yum install -y nmap-ncat
fi

if ! rpm -qi chrony ; then
    yum install -y chrony
    systemctl enable chrony
    systemctl start chrony
fi

env_file="/etc/environment"

if ! grep -q "/usr/local/bin" $env_file ; then
    echo "PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin" >> $env_file
fi

if [ "${SET_HTTP_PROXY}" = "true" ]; then
    lineinfile "^http_proxy=" "http_proxy=${HTTP_PROXY}" $env_file
    lineinfile "^HTTP_PROXY=" "HTTP_PROXY=${HTTP_PROXY}" $env_file
    lineinfile "^HTTPS_PROXY=" "HTTPS_PROXY=${HTTP_PROXY}" $env_file
else
    linefromfile "^http_proxy=" $env_file
    linefromfile "^HTTP_PROXY=" $env_file
    linefromfile "^HTTPS_PROXY=" $env_file
fi

setenforce 0 || true
lineinfile "^SELINUX=" "SELINUX=permissive" "/etc/selinux/config"