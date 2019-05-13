#!/bin/bash

set -e

if ! rpm -qi firewalld ; then
    yum install -y firewalld

    if ! systemctl is-active --quiet firewalld; then
        systemctl enable firewalld
        systemctl start firewalld
    fi
fi
