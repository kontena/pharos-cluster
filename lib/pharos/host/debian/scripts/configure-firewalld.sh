#!/bin/bash

set -e

if ! dpkg -l firewalld > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    systemctl mask ebtables
    apt-get install -y firewalld ipset
fi
