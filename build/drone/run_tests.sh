#!/bin/sh

set -ue

apt-get update -y
apt-get install -y -q cmake

bundle install --path bundler
bundle exec rspec spec/
SPEC_RETURN=$?

PRONTO_GITHUB_ACCESS_TOKEN=$GITHUB_TOKEN \
  PRONTO_PULL_REQUEST_ID=$DRONE_PULL_REQUEST \
  bundle exec pronto run -f github_status github_pr -c origin/master

exit $SPEC_RETURN
