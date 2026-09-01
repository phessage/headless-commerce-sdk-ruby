# 1Ecomm Ruby SDK and Rails Adapter

Framework-neutral Ruby client for the `/v1/headless/products` preview contract, with an optional Rails initializer/notifications adapter.

Run `ruby -Ilib test/client_test.rb`. Rails support is source-integrated but requires the CI Ruby/Rails matrix before it is called supported.
# 1ecomm Headless Commerce Ruby SDK

Framework-neutral Ruby client for the deployed catalog, anonymous-cart and checkout-preparation preview. See [Rails integration](docs/rails.md).

Use `Phessage::HeadlessCommerce::Client.for_store(store_id: 'your-site-uuid')` for one-field setup. Rails initializers can read only `HEADLESS_COMMERCE_STORE_ID`; the client resolves the public runtime document before making tenant-bound requests.

## Verification

```bash
ruby -Ilib test/client_test.rb
bundle exec ruby -Ilib test/rails_runtime_test.rb
HEADLESS_API_URL=https://api.1ecomm.com \
HEADLESS_PUBLISHABLE_KEY=pk_test_... \
HEADLESS_PRODUCT_ID=... ruby -Ilib test/live.rb
```

The live journey fails closed when its environment or known sellable fixture is missing. It creates an isolated cart and selects server-returned shipping/payment choices; it does not create an order or collect payment.
