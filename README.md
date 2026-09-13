# 1Ecomm Headless Commerce Ruby SDK and Rails Adapter

<!-- 1ecomm-discovery -->
> Part of **[1Ecomm headless commerce](https://www.1ecomm.com/headless-commerce)** — catalog, cart, checkout and order APIs for custom storefronts and apps.
> Fastest start: `npm create @1ecomm/storefront@latest` · [CLI guide](https://www.1ecomm.com/headless-commerce/cli.html) · [OpenAPI contract](https://www.1ecomm.com/headless-commerce/openapi.yaml) · [All starters and SDKs](https://www.1ecomm.com/headless-commerce#starters)

`create_customer_return` requires a caller-owned 1–120 character `idempotency_key:`. Reuse it with the identical request to recover the original RMA; changed return details fail with HTTP 409.

Free for authorized 1Ecomm customers and their developers to build and operate 1Ecomm-connected commerce experiences. You may deploy finished sites, but may not redistribute, resell, sublicense, mirror, or republish this SDK or a reusable derivative. See [LICENSE.md](LICENSE.md).

Preview gems are distributed through the private `phessage` GitHub Packages RubyGems registry and mirrored as immutable GitHub Release assets. Each release passes a clean gem-install smoke and carries a locked dependency manifest plus SHA-256 checksums. Public RubyGems.org publication remains disabled because the customer-use license prohibits downstream redistribution.

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

The client also covers customer auth configuration, password/OTP/native social sign-in, browser/mobile Google and Apple authorization-code exchange with S256 PKCE, refresh/logout, profile, cart merge, addresses, customer orders/cancellation and returns. Create each redirect attempt with `OAuthTransaction.create`, retain its state/verifier only in encrypted Rails/session storage, compare callback state before exchange, and delete it after either outcome. Access tokens last 15 minutes and refresh capabilities rotate on every use; keep them in encrypted Rails/session storage. Replaying a consumed refresh capability revokes its live family replacement, and logout revokes the family. This preview does not directly capture or initiate refunds. Hosted checkout and signed commerce events are platform capabilities. Pass the exact request body and headers to `WebhookVerifier.verify`, keep the `whsec_` secret server-side, and provide a replay store whose `claim` operation is atomic and backed by a unique delivery-ID constraint.

The gem carries a reviewed SHA-256-pinned copy of the production OpenAPI 3.1 contract. `ruby scripts/check_contract.rb` fails if that snapshot changes unexpectedly or loses the customer/problem schemas the SDK consumes. `ProblemError` preserves the stable problem `code`, validation `errors` and structured `fields` alongside request and rate-limit diagnostics. CI's deployed journey uses the allocator's synthetic customer—never production shopper data—to prove login projection redaction, profile, cart merge, address CRUD, eligible return creation/listing/cancellation, refresh rotation/replay rejection and logout in addition to guest checkout.

Password recovery uses `request_customer_password_recovery` and `reset_customer_password`. Requests are deliberately non-enumerating; a reset capability expires after one hour, works once and must never be logged.
