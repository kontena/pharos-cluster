#!/bin/bash

set -e

if systemctl is-active --quiet firewalld; then
    systemctl disable firewalld
    systemctl stop firewalld
fi
