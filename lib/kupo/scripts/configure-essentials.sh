#!/bin/bash

set -e

if ! dpkg -l apt-transport-https software-properties-common > /dev/null; then
    apt-get update -y
    apt-get install -y apt-transport-https software-properties-common
fi
