#!/bin/bash

set -e

if [ -e /usr/sbin/ntpd ]; then
    exit 0
fi

apt-get update
apt-get install -y ntp