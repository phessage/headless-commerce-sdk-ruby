#!/usr/bin/env bash
set -euo pipefail
release_dir="$(mktemp -d)"
trap 'rm -rf "$release_dir"' EXIT
gem build headless-commerce.gemspec --output "$release_dir/phessage-headless-commerce.gem"
gem install --install-dir "$release_dir/gems" --no-document "$release_dir/phessage-headless-commerce.gem"
GEM_HOME="$release_dir/gems" GEM_PATH="$release_dir/gems" ruby -e "require 'phessage/headless_commerce'; abort unless defined?(Phessage::HeadlessCommerce::Client) && defined?(Phessage::HeadlessCommerce::WebhookVerifier)"
printf 'Gem install smoke passed\n'
