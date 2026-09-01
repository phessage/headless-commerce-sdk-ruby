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
  def test_reads_retry_and_raise_typed_problem
    attempts = 0; transport = ->(*) { attempts += 1; attempts == 1 ? [503, '{}'] : [404, '{"type":"x","title":"Missing","requestId":"req_2"}'] }
    error = assert_raises(Phessage::HeadlessCommerce::ProblemError) { Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: transport, max_retries: 1).categories }
    assert_equal 404, error.status; assert_equal 'req_2', error.request_id; assert_equal 2, attempts
  end
  def test_rejects_confidential_key_and_invalid_cart_token
    assert_raises(ArgumentError) { Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'secret') }
    client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: ->(*) { flunk }); assert_raises(ArgumentError) { client.cart('invalid') }
  end
end
