#!/bin/bash

set -x

dpkg -l apt-transport-https software-properties-common > /dev/null

if [  $? != 0 ]; then
    apt-get update -y
    apt-get install -y apt-transport-https software-properties-common
fi