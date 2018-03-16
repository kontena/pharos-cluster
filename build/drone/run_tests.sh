#!/bin/bash

cd ..

bundle install --path bundler
bundle exec rspec spec/
SPEC_RETURN=$?

PRONTO_GITHUB_ACCESS_TOKEN=$GITHUB_TOKEN \
  PRONTO_PULL_REQUEST_ID=$DRONE_PULL_REQUEST \
  pronto run -f github_status github_pr -c origin/master

exit $SPEC_RETURN
