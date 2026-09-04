# Rails integration

For a return, persist one intent key with the pending action and reuse it only with the identical payload after an uncertain response; the SDK does not automatically retry the mutation.

The gem includes a Railtie and is exercised by `test/rails_runtime_test.rb` inside a real Rails application boot. Configure one client in an initializer using Rails encrypted credentials or environment-backed configuration:

```ruby
HEADLESS_COMMERCE = Phessage::HeadlessCommerce::Client.for_store(
  store_id: ENV.fetch('HEADLESS_COMMERCE_STORE_ID')
)
```

Keep each shopper's returned `hc_…` cart token in the encrypted Rails session and never place it in a URL or log. Keep customer access and refresh credentials there too, persist each replacement refresh capability, and clear both credentials on logout. Replaying a consumed refresh capability revokes its live family replacement; treat an unexpected refresh 401 as sign-in-required. An issued access token can remain valid for at most 15 minutes. Reads may retry eligible transient responses; mutations follow the documented idempotency policy. Verify signed events from the exact `request.raw_post` bytes with `WebhookVerifier.verify` before parsing or enqueueing work. Back `replay_store.claim` with a database unique constraint so concurrent Rails workers cannot repeat side effects.

For Google/Apple redirect login, create a fresh `Phessage::HeadlessCommerce::OAuthTransaction`, store its state/verifier and exact callback URI in the encrypted session, compare returned state before exchanging the code, and delete the pending transaction after success or failure.

Use `ProblemError#code` for failure control flow and retain `request_id` for support. Treat `errors` and `fields` as public validation diagnostics only; never log shopper credentials or send them with a support request. The reviewed contract snapshot is packaged with the gem for integration audits.
