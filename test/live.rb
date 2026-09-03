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
puts "Ruby deployed order journey passed and reopened: #{order['orderNumber']}"
rescue Phessage::HeadlessCommerce::ProblemError => error
  warn "Deployed API rejected the journey: status=#{error.status} type=#{error.type} requestId=#{error.request_id} message=#{error.message}"
  raise
end
