#!/bin/bash

set -e

. /opt/pharos/util.sh

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

if [ ! -e /opt/bin/nc ]; then
    mkdir -p /opt/bin
    ln -s /usr/bin/ncat /opt/bin/nc
fi

curl -fsSL https://bintray.com/user/downloadSubjectPublicKey?username=bintray | gpg --import -