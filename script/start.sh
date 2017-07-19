#!/bin/bash
BUNDLE_PATH=vendor/bundle
bundle check || bundle install --path vendor/bundle
bundle exec ./script/server
