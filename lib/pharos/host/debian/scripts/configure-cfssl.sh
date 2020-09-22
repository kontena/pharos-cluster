#!/bin/bash

set -e

if [ ! -d "/opt/pharos" ]; then
  mkdir /opt/pharos
fi

ctr -n pharos image pull "${IMAGE}"
ctr -n pharos install --path /opt/pharos --replace "${IMAGE}"

