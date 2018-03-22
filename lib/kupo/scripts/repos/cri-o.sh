#!/bin/sh

set -eu

if [ ! -e /etc/apt/sources.list.d/projectatomic-ubuntu-ppa-xenial.list ]; then
    add-apt-repository ppa:projectatomic/ppa
fi
