# 1Ecomm Headless Commerce Ruby SDK and Rails Adapter

Preview gems are distributed through the private `phessage` GitHub Packages RubyGems registry and mirrored as immutable GitHub Release assets. Each release passes a clean gem-install smoke and carries a locked dependency manifest plus SHA-256 checksums. Public RubyGems.org publication remains disabled while the source is private and proprietary.

Use this package for a Ruby or Rails website that sells products from a 1Ecomm store.

## Start

```bash
bundle install
ruby -Ilib test/client_test.rb
bundle exec ruby -Ilib test/rails_runtime_test.rb
```

```ruby
client = Phessage::HeadlessCommerce::Client.for_store(store_id: 'your-store-id')
products = client.list_products
order = client.lookup_order('ORD123', 'buyer@example.com')
```

The client discovers the correct public API settings from the store ID. A store ID is an identifier, not a password. Rails configuration is explained in [Rails integration](docs/rails.md).

Eligible reads and idempotent order placement use bounded exponential backoff and honor `Retry-After` up to 30 seconds. Ordinary mutations are never replayed. Typed errors prefer the authoritative `X-Request-Id` response header for support correlation.

Native HTTP requests default to a 10-second timeout; pass `timeout:` (maximum 120 seconds) to `Client.new` or `Client.for_store`. Custom transports must enforce their own deadline. `ProblemError#rate_limit` exposes normalized limit, remaining, reset, and retry-after diagnostics.

`ruby -Ilib test/live.rb` runs the complete maintained fixture journey with no environment setup: catalog, isolated cart, checkout choices and one pending bank-transfer test order. Set `HEADLESS_STORE_ID` only for another provisioned sandbox. The test does not charge money.

CI allocates a short-lived, repository-specific fixture and injects its publishable key and product ID into this journey, then revokes the key in an `always()` cleanup step. A missing allocator secret fails CI; it never silently skips deployed verification.

The SDK supports catalog, anonymous cart, guest checkout preparation, capability-gated non-hosted order placement and non-retrying guest order lookup. Keep the cart token in an encrypted server-side session. Reuse the same order intent key after an uncertain result. Never put the order number or checkout email in a URL or analytics event.

This preview does not directly capture/refund money or merge customer carts. Hosted checkout and signed commerce events are platform capabilities. Pass the exact request body and headers to `WebhookVerifier.verify`, keep the `whsec_` secret server-side, and provide a replay store whose `claim` operation is atomic and backed by a unique delivery-ID constraint.
