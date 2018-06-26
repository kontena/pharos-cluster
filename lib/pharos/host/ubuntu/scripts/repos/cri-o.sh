#!/bin/sh

set -eu

# Add bintray key to gpg
curl -fsSL https://bintray.com/user/downloadSubjectPublicKey?username=bintray | gpg --import

# remove deprecated ppa repository
if [ -e /etc/apt/sources.list.d/projectatomic-ubuntu-ppa-xenial.list ]; then	
    add-apt-repository --remove ppa:projectatomic/ppa
    rm /etc/apt/sources.list.d/projectatomic-ubuntu-ppa-xenial.list
fi