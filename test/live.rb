require_relative '../lib/phessage/headless_commerce'

base_url = ENV.fetch('HEADLESS_API_URL')
key = ENV.fetch('HEADLESS_PUBLISHABLE_KEY')
product_id = ENV.fetch('HEADLESS_PRODUCT_ID')
begin
client = Phessage::HeadlessCommerce::Client.new(base_url: base_url, publishable_key: key)
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
