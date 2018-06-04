#!/bin/bash

set -e

mkdir -p /opt/bin

if [ ! -f /opt/bin/cfssl ]; then
    curl -s -L -o /opt/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-${ARCH}
    echo eb34ab2179e0b67c29fd55f52422a94fe751527b06a403a79325fed7cf0145bd /opt/bin/cfssl | sha256sum -c
    chmod +x /opt/bin/cfssl
fi

if [ ! -f /opt/bin/cfssljson ]; then
    curl -s -L -o /opt/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-${ARCH}
    echo 1c9e628c3b86c3f2f8af56415d474c9ed4c8f9246630bd21c3418dbe5bf6401e /opt/bin/cfssljson | sha256sum -c
    chmod +x /opt/bin/cfssljson
fi