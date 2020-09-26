#!/bin/bash

set -e

mkdir -p /opt/pharos
ctr -n pharos image pull "${IMAGE}"
ctr -n pharos install --path /opt/pharos --replace "${IMAGE}"

