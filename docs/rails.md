# Rails integration

The gem includes a Railtie and is exercised by `test/rails_runtime_test.rb` inside a real Rails application boot. Configure one client in an initializer using Rails encrypted credentials or environment-backed configuration:

```ruby
HEADLESS_COMMERCE = Phessage::HeadlessCommerce::Client.for_store(
  store_id: ENV.fetch('HEADLESS_COMMERCE_STORE_ID')
)
```

Keep each shopper's returned `hc_…` cart token in the encrypted Rails session and never place it in a URL or log. Reads may retry eligible transient responses; mutations never retry automatically. Order finalization, payment capture and public webhooks are not part of the preview. Do not add an Active Job webhook consumer until signature verification and duplicate-event handling ship.
