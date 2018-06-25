#!/bin/sh

set -eu

# Add bintray key to gpg
curl -fsSL https://bintray.com/user/downloadSubjectPublicKey?username=bintray | gpg --import
