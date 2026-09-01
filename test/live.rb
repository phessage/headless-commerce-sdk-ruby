require_relative '../lib/phessage/headless_commerce'

store_id = ENV.fetch('HEADLESS_STORE_ID', '01f5b02f-d7c0-42cd-b880-59f78ea70aa3')
product_id = ENV.fetch('HEADLESS_PRODUCT_ID', '1f7884bd-759d-4f47-9fdb-c7ea3dd3a9ef')
begin
client = Phessage::HeadlessCommerce::Client.for_store(store_id: store_id)
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
raise 'Expected deployed shipping/payment choices' if shipping.empty? || payment.empty?
client.select_shipping_method(token, shipping.first.fetch('id')); final = client.select_payment_method(token, payment.first.fetch('id')).fetch('data')
raise "Checkout preparation remains incomplete: #{final['missing']}" unless final['ready']
puts "Ruby deployed journey passed: #{shipping.length} shipping, #{payment.length} payment choice(s)"
rescue Phessage::HeadlessCommerce::ProblemError => error
  warn "Deployed API rejected the journey: status=#{error.status} type=#{error.type} requestId=#{error.request_id} message=#{error.message}"
  raise
end
