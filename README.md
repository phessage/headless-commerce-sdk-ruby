# 1Ecomm Headless Commerce Ruby SDK and Rails Adapter

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
```

The client discovers the correct public API settings from the store ID. A store ID is an identifier, not a password. Rails configuration is explained in [Rails integration](docs/rails.md).

`ruby -Ilib test/live.rb` runs the complete maintained fixture journey with no environment setup: catalog, isolated cart, checkout choices and one pending bank-transfer test order. Set `HEADLESS_STORE_ID` only for another provisioned sandbox. The test does not charge money.

The SDK supports catalog, anonymous cart, guest checkout preparation and capability-gated non-hosted order placement. Keep the cart token in an encrypted server-side session. Reuse the same order intent key after an uncertain result.

This preview does not collect card/wallet payments, capture/refund money, merge customer carts, or deliver webhooks.
