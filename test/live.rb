require_relative '../lib/phessage/headless_commerce'
require 'securerandom'

store_id = ENV.fetch('HEADLESS_STORE_ID', '01f5b02f-d7c0-42cd-b880-59f78ea70aa3')
product_id = ENV.fetch('HEADLESS_PRODUCT_ID', '1f7884bd-759d-4f47-9fdb-c7ea3dd3a9ef')
begin
key = ENV.fetch('HEADLESS_PUBLISHABLE_KEY', '')
client = key.empty? ? Phessage::HeadlessCommerce::Client.for_store(store_id: store_id) : Phessage::HeadlessCommerce::Client.new(base_url: ENV.fetch('HEADLESS_API_URL', 'https://api.1ecomm.com'), publishable_key: key)
products = client.list_products(limit: 100).fetch('data')
raise 'Known sellable product is absent' unless products.any? { |product| product['id'] == product_id && product['available'] }
created = client.create_cart
token = created.fetch('cartToken')
client.add_cart_item(token, product_id: product_id)
prepared = client.update_checkout_details(token, {
  customerInfo: { email: 'headless-ruby-live@example.test', firstName: 'Ruby', lastName: 'Journey' },
  billingAddress: { firstName: 'Ruby', lastName: 'Journey', email: 'headless-ruby-live@example.test', address1: '1 Test Way', city: 'Vancouver', state: 'BC', postalCode: 'V6B1A1', country: 'CA' },
  shippingAddress: { sameAsBilling: true }
}).fetch('data')
shipping = prepared.fetch('shippingOptions'); payment = prepared.fetch('paymentMethods')
raise 'Expected a deployed payment choice' if payment.empty?
client.select_shipping_method(token, shipping.first.fetch('id')) unless shipping.empty?
final = client.select_payment_method(token, payment.first.fetch('id')).fetch('data')
raise "Checkout preparation remains incomplete: #{final['missing']}" unless final['ready']
order = client.place_order(token, "ruby-live-#{SecureRandom.uuid}").fetch('data')
raise 'Pending order confirmation missing' unless order['requiresPayment'] == false && order['paymentStatus'] == 'pending'
reopened = client.lookup_order(order.fetch('orderNumber'), 'headless-ruby-live@example.test').fetch('data')
raise 'Created order could not be reopened' unless reopened['orderNumber'] == order['orderNumber']
customer_email = ENV.fetch('HEADLESS_CUSTOMER_EMAIL', '')
customer_password = ENV.fetch('HEADLESS_CUSTOMER_PASSWORD', '')
unless customer_email.empty? || customer_password.empty?
  customer_cart = client.create_cart
  client.add_cart_item(customer_cart.fetch('cartToken'), product_id: product_id)
  auth = client.login_customer(email: customer_email, password: customer_password, cart_token: customer_cart.fetch('cartToken')).fetch('data')
  raise 'Customer authentication projection drifted' unless auth.keys.sort == %w[cartInfo customer expiresIn refreshToken token].sort
  raise 'Customer profile projection drifted' unless auth.fetch('customer').keys.sort == %w[id email firstName lastName phone avatarUrl emailVerified].sort
  assert_error = begin
    client.customer_profile('')
    nil
  rescue ArgumentError => error
    error
  end
  raise 'Missing customer token was accepted' unless assert_error
  profile = client.update_customer_profile(auth.fetch('token'), { firstName: 'Ruby E2E' }).fetch('data')
  raise 'Customer profile update failed' unless profile['firstName'] == 'Ruby E2E'
  merged = client.merge_customer_cart(auth.fetch('token'), customer_cart.fetch('cartToken')).fetch('data')
  raise 'Customer cart merge failed' unless merged['merged'] && merged['cartToken'].to_s.start_with?('hc_')
  address = client.create_customer_address(auth.fetch('token'), { firstName: 'Ruby', lastName: 'E2E', address1: '1 Fixture Way', city: 'Vancouver', province: 'BC', country: 'CA', zip: 'V6B1A1', setDefault: true }).dig('data', 'address')
  raise 'Customer address creation failed' unless address['id'] && address['isDefault']
  updated = client.update_customer_address(auth.fetch('token'), address.fetch('id'), { address2: 'Suite Ruby' }).dig('data', 'address')
  raise 'Customer address update failed' unless updated['address2'] == 'Suite Ruby'
  addresses = client.customer_addresses(auth.fetch('token')).dig('data', 'addresses')
  raise 'Customer address list failed' unless addresses.any? { |entry| entry['id'] == address['id'] }
  return_order_id = ENV.fetch('HEADLESS_RETURN_ORDER_ID', '')
  return_order_item_id = ENV.fetch('HEADLESS_RETURN_ORDER_ITEM_ID', '')
  raise 'Eligible return fixture missing' if return_order_id.empty? || return_order_item_id.empty?
  return_intent = "customer-return:#{ENV['GITHUB_RUN_ID'] || SecureRandom.uuid}"
  return_input = { reason: 'not_as_expected', items: [{ orderItemId: return_order_item_id, quantity: 1, resolution: 'refund' }] }
  return_request = client.create_customer_return(auth.fetch('token'), return_order_id, return_input, idempotency_key: return_intent).dig('data', 'return')
  replayed_return = client.create_customer_return(auth.fetch('token'), return_order_id, return_input, idempotency_key: return_intent).dig('data', 'return')
  raise 'Return creation did not replay the original request' unless replayed_return['id'] == return_request['id']
  begin
    client.create_customer_return(auth.fetch('token'), return_order_id, return_input.merge(note: 'different intent'), idempotency_key: return_intent)
    raise 'return key reuse with a different payload did not conflict'
  rescue Phessage::HeadlessCommerce::ProblemError => e
    raise 'Different return intent did not return 409' unless e.status == 409
  end
  raise 'Return creation projection drifted' unless return_request['orderId'] == return_order_id && return_request['status'] == 'requested'
  order_returns = client.customer_order_returns(auth.fetch('token'), return_order_id).dig('data', 'returns')
  raise 'Return missing from order history' unless order_returns.any? { |entry| entry['id'] == return_request['id'] }
  customer_returns = client.customer_returns(auth.fetch('token')).dig('data', 'returns')
  raise 'Return missing from customer history' unless customer_returns.any? { |entry| entry['id'] == return_request['id'] }
  cancelled_return = client.cancel_customer_return(auth.fetch('token'), return_request.fetch('id')).dig('data', 'return')
  raise 'Return cancellation projection drifted' unless cancelled_return['status'] == 'cancelled'
  raise 'Customer address deletion failed' unless client.delete_customer_address(auth.fetch('token'), address.fetch('id')).dig('data', 'deleted')
  rotated = client.refresh_customer(auth.fetch('refreshToken')).fetch('data')
  begin
    client.refresh_customer(auth.fetch('refreshToken'))
    raise 'Consumed refresh token was accepted'
  rescue Phessage::HeadlessCommerce::ProblemError => error
    raise 'Refresh replay problem contract failed' unless error.status == 401 && error.code == 'HEADLESS_HTTP_401'
  end
  begin
    client.refresh_customer(rotated.fetch('refreshToken'))
    raise 'Refresh family survived ancestor replay'
  rescue Phessage::HeadlessCommerce::ProblemError => error
    raise 'Refresh family revocation contract failed' unless error.status == 401 && error.code == 'HEADLESS_HTTP_401'
  end
  raise 'Customer logout failed' unless client.logout_customer(rotated.fetch('refreshToken')).dig('data', 'loggedOut')
end
puts "Ruby deployed guest and customer journeys passed and reopened: #{order['orderNumber']}"
rescue Phessage::HeadlessCommerce::ProblemError => error
  warn "Deployed API rejected the journey: status=#{error.status} type=#{error.type} requestId=#{error.request_id} message=#{error.message}"
  raise
end
