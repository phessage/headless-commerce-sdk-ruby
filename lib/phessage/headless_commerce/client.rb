require 'json'
require 'net/http'
require 'uri'
require 'time'

module Phessage
  module HeadlessCommerce
    class ProblemError < StandardError
      attr_reader :status, :type, :request_id, :rate_limit
      def initialize(status, problem, request_id = nil, rate_limit = {})
        @status = status; @type = problem['type'] || 'about:blank'; @request_id = request_id || problem['requestId']
        @rate_limit = rate_limit
        super(problem['detail'] || problem['title'] || 'Request failed')
      end
    end

    class Client
      RETRYABLE_STATUSES = [429, 502, 503, 504].freeze
      def self.for_store(store_id:, bootstrap_url: 'https://api.1ecomm.com', transport: nil, max_retries: 2, timeout: 10)
        raise ArgumentError, 'timeout must be between 0 and 120 seconds' unless timeout.to_f.positive? && timeout.to_f <= 120
        uri = URI("#{bootstrap_url.sub(%r{/$}, '')}/v1/headless/stores/#{URI.encode_www_form_component(store_id)}/config")
        status, body = if transport
                         transport.call(uri.to_s, { 'Accept' => 'application/json' }, 'GET', nil)
                       else
                         response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: timeout, read_timeout: timeout) { |http| http.get(uri.request_uri) }; [response.code.to_i, response.body]
                       end
        raise "Headless store bootstrap failed (#{status})" unless status == 200
        runtime = JSON.parse(body).fetch('data')
        raise 'Invalid headless store bootstrap response' unless runtime['storeId'] == store_id && runtime['publishableKey'].to_s.start_with?('pk_')
        new(base_url: runtime.fetch('apiUrl'), publishable_key: runtime.fetch('publishableKey'), transport: transport, max_retries: max_retries, timeout: timeout)
      end
      def initialize(base_url:, publishable_key:, transport: nil, max_retries: 2, timeout: 10)
        raise ArgumentError, 'A base URL and publishable key are required' if base_url.to_s.empty? || !publishable_key.start_with?('pk_')
        raise ArgumentError, 'timeout must be between 0 and 120 seconds' unless timeout.to_f.positive? && timeout.to_f <= 120
        @base_url = base_url.sub(%r{/$}, ''); @key = publishable_key; @transport = transport; @max_retries = max_retries; @timeout = timeout
      end

      def list_products(limit: 20, cursor: nil, query: nil)
        params = { limit: [[limit.to_i, 1].max, 100].min }; params[:cursor] = cursor if cursor; params[:query] = query.strip unless query.to_s.strip.empty?
        request('GET', "/v1/headless/products?#{URI.encode_www_form(params)}", retry_safe: true)
      end
      def product(id) = request('GET', "/v1/headless/products/#{URI.encode_www_form_component(id)}", retry_safe: true)
      def categories = request('GET', '/v1/headless/products/categories', retry_safe: true)
      def create_cart = request('POST', '/v1/headless/carts')
      def cart(cart_token) = cart_request('GET', '/v1/headless/carts/current', cart_token, retry_safe: true)
      def add_cart_item(cart_token, product_id:, quantity: 1, variant_id: nil)
        body = { productId: product_id, quantity: quantity }; body[:variantId] = variant_id if variant_id
        cart_request('POST', '/v1/headless/carts/current/items', cart_token, body: body)
      end
      def update_cart_item(cart_token, item_id:, quantity:) = cart_request('PATCH', "/v1/headless/carts/current/items/#{URI.encode_www_form_component(item_id)}", cart_token, body: { quantity: quantity })
      def remove_cart_item(cart_token, item_id:) = cart_request('DELETE', "/v1/headless/carts/current/items/#{URI.encode_www_form_component(item_id)}", cart_token)
      def checkout_preparation(cart_token) = cart_request('GET', '/v1/headless/carts/current/checkout', cart_token, retry_safe: true)
      def update_checkout_details(cart_token, details) = cart_request('PATCH', '/v1/headless/carts/current/checkout', cart_token, body: details)
      def select_shipping_method(cart_token, id) = cart_request('PUT', '/v1/headless/carts/current/checkout/shipping-method', cart_token, body: { id: id })
      def select_payment_method(cart_token, id) = cart_request('PUT', '/v1/headless/carts/current/checkout/payment-method', cart_token, body: { id: id })
      def place_order(cart_token, idempotency_key)
        key = idempotency_key.to_s.strip
        raise ArgumentError, 'An idempotency key of 1-120 characters is required' if key.empty? || key.length > 120
        cart_request('POST', '/v1/headless/carts/current/checkout/order', cart_token, retry_safe: true, headers: { 'Idempotency-Key' => key })
      end
      def lookup_order(order_number, email)
        number = order_number.to_s.strip; address = email.to_s.strip
        raise ArgumentError, 'An order number and valid checkout email are required' if number.empty? || address !~ /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
        request('POST', '/v1/headless/orders/lookup', body: { orderNumber: number, email: address })
      end

      private
      def cart_request(method, path, token, body: nil, retry_safe: false, headers: {})
        raise ArgumentError, 'A cart capability token is required' unless token.to_s.start_with?('hc_')
        request(method, path, body: body, cart_token: token, retry_safe: retry_safe, headers: headers)
      end
      def request(method, path, body: nil, cart_token: nil, retry_safe: false, headers: {})
        attempts = retry_safe ? @max_retries + 1 : 1
        attempts.times do |attempt|
          status, response_body, response_headers = send_request(URI(@base_url + path), method, body, cart_token, headers)
          return JSON.parse(response_body) if status.between?(200, 299)
          if retry_safe && RETRYABLE_STATUSES.include?(status) && attempt + 1 < attempts
            wait_before_retry(response_headers || {}, attempt)
            next
          end
          problem = JSON.parse(response_body) rescue {}
          request_id = response_headers&.find { |name, _| name.downcase == 'x-request-id' }&.last
          raise ProblemError.new(status, problem, request_id, rate_limit(response_headers || {}))
        end
        raise 'unreachable'
      end
      def send_request(uri, method, body, cart_token, extra_headers = {})
        headers = { 'Accept' => 'application/json', 'x-publishable-key' => @key }.merge(extra_headers); headers['x-cart-token'] = cart_token if cart_token; headers['Content-Type'] = 'application/json' if body
        encoded = body && JSON.generate(body)
        return @transport.call(uri.to_s, headers, method, encoded) if @transport
        request = Net::HTTP.const_get(method.capitalize).new(uri); headers.each { |name, value| request[name] = value }; request.body = encoded if encoded
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: @timeout, read_timeout: @timeout) { |http| http.request(request) }
        [response.code.to_i, response.body, response.each_header.to_h]
      end
      def wait_before_retry(headers, attempt)
        retry_after = headers.find { |name, _| name.downcase == 'retry-after' }&.last
        delay = if retry_after&.match?(/\A\d+(?:\.\d+)?\z/)
                  retry_after.to_f
                elsif retry_after
                  [Time.httpdate(retry_after) - Time.now, 0].max rescue nil
                end
        delay ||= [0.25 * (2**attempt) + rand(0.0..0.1), 30].min
        sleep([delay, 30].min) if delay.positive?
      end
      def rate_limit(headers)
        value = ->(name) { headers.find { |key, _| key.downcase == name }&.last }
        number = ->(name) { raw = value.call(name); raw&.match?(/\A\d+\z/) ? raw.to_i : nil }
        { limit: number.call('ratelimit-limit'), remaining: number.call('ratelimit-remaining'), reset: number.call('ratelimit-reset'), retry_after: value.call('retry-after') }
      end
    end
  end
end
