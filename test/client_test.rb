require 'minitest/autorun'
require_relative '../lib/phessage/headless_commerce'

class ClientTest < Minitest::Test
  TOKEN = 'hc_' + ('a' * 43)
  def test_store_id_bootstrap
    calls = []; transport = ->(url, headers, method, body) { calls << [url, headers, method, body]; [200, '{"data":{"storeId":"store-a","apiUrl":"https://sandbox.test","publishableKey":"pk_test_demo","apiVersion":"v1","capabilities":["catalog","cart","checkout-preparation"]}}'] }
    Phessage::HeadlessCommerce::Client.for_store(store_id: 'store-a', transport: transport)
    assert calls.first[0].end_with?('/v1/headless/stores/store-a/config'); assert_equal 'GET', calls.first[2]
  end
  def test_catalog_routes_and_headers
    calls = []; transport = ->(url, headers, method, body) { calls << [url, headers, method, body]; [200, '{"data":[],"requestId":"r"}'] }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport)
    client.list_products(limit: 999, query: ' pack '); client.product('p/1'); client.categories
    assert_includes calls[0][0], 'limit=100&query=pack'; assert_equal 'pk_test_demo', calls[0][1]['x-publishable-key']; assert calls[1][0].end_with?('/p%2F1')
  end
  def test_cart_and_checkout_routes
    calls = []; transport = ->(url, headers, method, body) { calls << [url, headers, method, body]; [200, '{"data":{},"requestId":"r"}'] }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport)
    client.create_cart; client.add_cart_item(TOKEN, product_id: 'product-1', quantity: 2); client.update_cart_item(TOKEN, item_id: 'line/1', quantity: 3); client.remove_cart_item(TOKEN, item_id: 'line/1'); client.checkout_preparation(TOKEN); client.update_checkout_details(TOKEN, { contact: { email: 'shopper@example.test' } }); client.select_shipping_method(TOKEN, 'ship-1'); client.select_payment_method(TOKEN, 'pay-1')
    assert_equal %w[POST POST PATCH DELETE GET PATCH PUT PUT], calls.map { |call| call[2] }; assert_equal TOKEN, calls[1][1]['x-cart-token']; assert_equal 2, JSON.parse(calls[1][3])['quantity']; assert calls[2][0].end_with?('/line%2F1')
  end
  def test_mutations_are_never_retried
    attempts = 0; client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', max_retries: 2, transport: ->(*) { attempts += 1; [503, '{}'] })
    assert_raises(Phessage::HeadlessCommerce::ProblemError) { client.create_cart }; assert_equal 1, attempts
  end
  def test_order_retries_only_with_same_intent_key
    calls = []; attempts = 0
    transport = ->(url, headers, method, body) { calls << [url, headers, method, body]; attempts += 1; attempts == 1 ? [503, '{}'] : [201, '{"data":{"orderNumber":"ORD1","requiresPayment":false},"requestId":"r"}'] }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport, max_retries: 1)
    assert_equal 'ORD1', client.place_order(TOKEN, 'intent-1').dig('data', 'orderNumber')
    assert_equal ['intent-1', 'intent-1'], calls.map { |call| call[1]['Idempotency-Key'] }
    assert calls.all? { |call| call[0].end_with?('/checkout/order') && call[2] == 'POST' }
    assert_raises(ArgumentError) { client.place_order(TOKEN, ' ') }
  end
  def test_reads_retry_and_raise_typed_problem
    attempts = 0; transport = ->(*) { attempts += 1; attempts == 1 ? [503, '{}', { 'Retry-After' => '0' }] : [404, '{"type":"x","title":"Missing","requestId":"body-id","code":"PRODUCT_MISSING","errors":["not found"],"fields":{"id":"unknown"}}', { 'X-Request-Id' => 'header-id', 'RateLimit-Limit' => '100', 'RateLimit-Remaining' => '0', 'RateLimit-Reset' => '42', 'Retry-After' => '7' }] }
    error = assert_raises(Phessage::HeadlessCommerce::ProblemError) { Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport, max_retries: 1).categories }
    assert_equal 404, error.status; assert_equal 'header-id', error.request_id; assert_equal 2, attempts
    assert_equal({ limit: 100, remaining: 0, reset: 42, retry_after: '7' }, error.rate_limit)
    assert_equal 'PRODUCT_MISSING', error.code; assert_equal ['not found'], error.errors; assert_equal({ 'id' => 'unknown' }, error.fields)
  end
  def test_guest_order_lookup_is_a_non_retried_post
    calls = []; client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', max_retries: 2, transport: ->(url, headers, method, body) { calls << [url, headers, method, body]; [201, '{"data":{"orderNumber":"ORD1","status":"pending"},"requestId":"r"}'] })
    assert_equal 'ORD1', client.lookup_order(' ORD1 ', 'buyer@example.test').dig('data', 'orderNumber')
    assert_equal 1, calls.length; assert calls.first[0].end_with?('/v1/headless/orders/lookup'); assert_equal 'POST', calls.first[2]
    assert_equal({ 'orderNumber' => 'ORD1', 'email' => 'buyer@example.test' }, JSON.parse(calls.first[3]))
    assert_raises(ArgumentError) { client.lookup_order('ORD1', 'bad') }
  end
  def test_customer_route_and_header_parity
    calls = []; transport = ->(url, headers, method, body) { calls << [url, headers, method, body]; [200, '{"data":{},"requestId":"r"}'] }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport)
    client.login_customer(email: 'buyer@example.test', password: 'password1', cart_token: TOKEN)
    client.refresh_customer('a' * 64); client.customer_profile('customer-jwt'); client.merge_customer_cart('customer-jwt', TOKEN)
    client.customer_orders('customer-jwt', page: 2, limit: 10, status: 'pending'); client.create_customer_return('customer-jwt', 'order/1', { items: [{ orderItemId: 'line-1', quantity: 1 }] }, idempotency_key: 'return-intent-1')
    assert_equal %w[POST POST GET POST GET POST], calls.map { |call| call[2] }
    assert_equal TOKEN, calls[0][1]['x-cart-token']; assert_equal 'customer-jwt', calls[2][1]['x-customer-token']; assert_equal 'return-intent-1', calls[5][1]['Idempotency-Key']
    assert_includes calls[4][0], 'page=2&limit=10&status=pending'; assert calls[5][0].include?('/orders/order%2F1/returns')
  end
  def test_rejects_invalid_return_idempotency_key_without_a_request
    calls = []; transport = ->(url, headers, method, body) { calls << [url, headers, method, body]; [200, '{}'] }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport)
    assert_raises(ArgumentError) { client.create_customer_return('customer-jwt', 'order-1', { items: [] }, idempotency_key: ' ') }
    assert_empty calls
  end
  def test_rejects_confidential_key_and_invalid_cart_token
    assert_raises(ArgumentError) { Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'secret') }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: ->(*) { flunk }); assert_raises(ArgumentError) { client.cart('invalid') }
  end
  def test_webhook_verification_and_replay_claim
    timestamp = 1_788_480_000; envelope = { 'id' => 'delivery-1', 'event' => 'order.paid', 'installationId' => nil, 'applicationId' => 'app-1', 'siteId' => 'site-1', 'occurredAt' => '2026-09-04T00:00:00.000Z', 'data' => { 'orderId' => 'order-1' } }; raw = JSON.generate(envelope); secret = 'whsec_test_receiver_secret'; signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{raw}")}"; headers = { 'X-Headless-Webhook-Timestamp' => timestamp.to_s, 'X-Headless-Webhook-Signature' => signature, 'X-Headless-Webhook-Id' => 'delivery-1' }; claims = []
    result = Phessage::HeadlessCommerce::WebhookVerifier.verify(raw_body: raw, headers: headers, secret: secret, now: Time.at(timestamp), replay_store: ->(id, _) { claims << id; true })
    assert_equal 'order-1', result.dig('data', 'orderId'); assert_equal ['delivery-1'], claims
    error = assert_raises(Phessage::HeadlessCommerce::WebhookVerificationError) { Phessage::HeadlessCommerce::WebhookVerifier.verify(raw_body: "#{raw} ", headers: headers, secret: secret, now: Time.at(timestamp)) }; assert_equal :invalid_signature, error.reason
    error = assert_raises(Phessage::HeadlessCommerce::WebhookVerificationError) { Phessage::HeadlessCommerce::WebhookVerifier.verify(raw_body: raw, headers: headers, secret: secret, now: Time.at(timestamp + 301)) }; assert_equal :stale_timestamp, error.reason
    error = assert_raises(Phessage::HeadlessCommerce::WebhookVerificationError) { Phessage::HeadlessCommerce::WebhookVerifier.verify(raw_body: raw, headers: headers, secret: secret, now: Time.at(timestamp), replay_store: ->(*) { false }) }; assert_equal :replayed_delivery, error.reason
  end
end
