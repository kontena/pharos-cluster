#!/bin/bash

set -x

dpkg -l ntp apt-transport-https software-properties-common > /dev/null

if [  $? != 0 ]; then
    apt-get update -y
    apt-get install -y ntp apt-transport-https software-properties-common
fi