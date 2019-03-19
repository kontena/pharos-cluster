#!/bin/bash

set -e

env

if [ ! -f /usr/local/bin/cfssl ]; then
    curl -s -L -o /usr/local/bin/cfssl "https://dl.bintray.com/kontena/pharos-bin/cfssl/1.2/cfssl_linux-${ARCH}"
    echo eb34ab2179e0b67c29fd55f52422a94fe751527b06a403a79325fed7cf0145bd /usr/local/bin/cfssl | sha256sum -c
    chmod +x /usr/local/bin/cfssl
fi

if [ ! -f /usr/local/bin/cfssljson ]; then
    curl -s -L -o /usr/local/bin/cfssljson "https://dl.bintray.com/kontena/pharos-bin/cfssl/1.2/cfssljson_linux-${ARCH}"
    echo 1c9e628c3b86c3f2f8af56415d474c9ed4c8f9246630bd21c3418dbe5bf6401e /usr/local/bin/cfssljson | sha256sum -c
    chmod +x /usr/local/bin/cfssljson
fi
