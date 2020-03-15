#!/bin/bash

set -e

ctr -n pharos image pull "${IMAGE}"
ctr -n pharos install --path /opt/pharos --replace "${IMAGE}"

