#!/bin/bash

set -e

if ! dpkg -l firewalld > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y firewalld ipset ebtables
    if ! systemctl is-active --quiet firewalld; then
        systemctl enable firewalld
        systemctl start firewalld
    fi
fi
