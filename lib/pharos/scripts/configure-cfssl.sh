#!/bin/bash

set -e

if [ "${ARCH}" = "amd64" ]; then
    MIRROR="http://mirrors.kernel.org/ubuntu"
else
    MIRROR="http://ports.ubuntu.com"
fi

CFSSL_URL="${MIRROR}/pool/universe/g/golang-github-cloudflare-cfssl/golang-cfssl_${VERSION:?"Need to set VERSION"}_${ARCH}.deb"

if [ ! -e  /usr/bin/cfssl ]; then
    curl -sL -o /tmp/cfssl.deb ${CFSSL_URL}
    dpkg -i /tmp/cfssl.deb && rm /tmp/cfssl.deb
fi