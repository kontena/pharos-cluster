#!/bin/bash

set -ex

sudo apt-get update -y
sudo apt-get install -y build-essential libyaml-dev desktop-file-utils curl wget file
sudo curl -o /usr/local/bin/pkg2appimage https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage
sudo chmod +x /usr/local/bin/pkg2appimage
pkg2appimage ./build/travis/appimage.yml
