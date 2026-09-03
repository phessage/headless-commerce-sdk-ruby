# AI engineering guide

Read `README.md`, `docs/rails.md`, the gemspec, `lib/*` and all tests before editing.

## Boundary and contract

This is a Ruby 3.1+ SDK with an optional Rails Railtie. Canonical API truth is `phessage/ecommerce-service/contracts/headless-commerce-v1.openapi.yaml`. Rails support configures the shared client; it must not hide routes, callbacks or network work.

Preserve store bootstrap, key-derived tenant scope, cart bearer-token secrecy, non-retry of mutations/lookup and same-key-only retry of uncertain order placement. Parse documented shapes only: guest order count is `items.length`, not `itemCount`.

Signed outbound webhooks are deployed. Receiver code verifies the exact raw body, timestamp, HMAC and delivery-ID binding before parsing or side effects, then atomically claims the delivery ID in durable storage.

## Ruby/Rails practices

- Use frozen string literals, keyword arguments for public APIs, small objects and explicit error classes.
- Treat decoded JSON as untrusted. Validate required keys/types and preserve server problem/request metadata.
- Configure TLS verification plus open/read timeouts; bound redirects and never log credentials, tokens or shopper proof.
- Avoid global mutable configuration. The Railtie should use normal Rails configuration and lazy initialization.
- Keep support aligned with the gemspec's Ruby floor and CI matrix. Update `Gemfile.lock` with dependency changes and do not weaken constraints just to resolve locally.

## License boundary

`LICENSE.md` allows authorized 1Ecomm customer projects and deployed or compiled shopper applications, but prohibits redistribution of this reusable SDK/plugin or its derivatives. Preserve the notice in clones, packages, generated projects and documentation. Do not describe this repository as open source or grant broader rights in examples.

## Verification

Run `bundle install`, `bundle exec ruby -Ilib test/client_test.rb`, and `bundle exec ruby -Ilib test/rails_runtime_test.rb`; run `ruby -Ilib test/live.rb` only against the maintained sandbox. A Rails change requires a real application boot. Distinguish local tests from deployed live proof.

## Releases

`.github/workflows/release.yml` is the only gem publisher. It requires the protected `package-release` environment, an exact gemspec version and unused immutable tag; it runs Ruby/Rails tests and a clean gem-install smoke before publishing to the restricted `phessage` GitHub Packages RubyGems registry and attaching the gem, dependency manifest and checksums to the GitHub Release. Never publish this proprietary gem to public RubyGems.org, move a tag or replace a released version without an explicit licensing/distribution decision.
