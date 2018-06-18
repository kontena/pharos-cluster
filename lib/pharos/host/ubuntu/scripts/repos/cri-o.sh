#!/bin/sh

set -eu

if [ ! -e /etc/apt/sources.list.d/projectatomic-ubuntu-ppa-xenial.list ]; then
    add-apt-repository ppa:projectatomic/ppa
fi

# Add bintray key to gpg
curl -fsSL https://bintray.com/user/downloadSubjectPublicKey?username=bintray | gpg --import
