#!/bin/bash

set -e

if ! rpm -qi firewalld ; then
    yum install -y firewalld
fi
