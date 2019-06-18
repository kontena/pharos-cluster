#!/bin/bash
# shellcheck disable=SC2039 disable=SC1091

set -u

if [ ! -f e2e/digitalocean/tf.json ]
then
    echo "TF output not found, skipping."
    exit 0
fi

export PHAROS_NON_OSS=true

gem build pharos-cluster.gemspec
gem install pharos-cluster*.gem

# Test that we can actually load everything
pharos || exit $?
pharos -v || exit $?
pharos version || exit $?

# Smoke the license commands
pharos license assign --help || exit $?
pharos license inspect --help || exit $?
