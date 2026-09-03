# frozen_string_literal: true
require 'json'
require 'openssl'

module Phessage
  module HeadlessCommerce
    class WebhookVerificationError < StandardError
      attr_reader :reason
      def initialize(reason, message); @reason = reason; super(message); end
    end

    module WebhookVerifier
      module_function
      def verify(raw_body:, headers:, secret:, replay_store: nil, tolerance_seconds: 300, now: Time.now)
        normalized = headers.each_with_object({}) { |(key, value), memo| memo[key.to_s.downcase] = Array(value).first.to_s }
        timestamp = normalized['x-headless-webhook-timestamp']; signature = normalized['x-headless-webhook-signature']; delivery_id = normalized['x-headless-webhook-id']
        raise WebhookVerificationError.new(:invalid_headers, 'Required webhook headers are missing or malformed') unless timestamp&.match?(/\A\d{1,16}\z/) && !signature.to_s.empty? && !delivery_id.to_s.empty?
        raise ArgumentError, 'tolerance_seconds must be between 0 and 3600' unless (0..3600).cover?(tolerance_seconds)
        raise WebhookVerificationError.new(:stale_timestamp, 'Webhook timestamp is outside the accepted tolerance') if (now.to_i - timestamp.to_i).abs > tolerance_seconds
        expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{raw_body}")}" if secret.start_with?('whsec_')
        raise WebhookVerificationError.new(:invalid_signature, 'Webhook signature is invalid') unless expected && secure_equal(expected, signature)
        begin envelope = JSON.parse(raw_body); rescue JSON::ParserError; raise WebhookVerificationError.new(:invalid_payload, 'Webhook body is not valid JSON'); end
        valid = envelope.is_a?(Hash) && envelope['id'] == delivery_id && %w[event applicationId siteId occurredAt].all? { |key| envelope[key].is_a?(String) }
        raise WebhookVerificationError.new(:invalid_payload, 'Webhook envelope does not match its delivery headers') unless valid
        claimed = replay_store.respond_to?(:claim) ? replay_store.claim(delivery_id, envelope['occurredAt']) : replay_store&.call(delivery_id, envelope['occurredAt'])
        raise WebhookVerificationError.new(:replayed_delivery, 'Webhook delivery was already processed') if replay_store && !claimed
        envelope
      end

      def secure_equal(left, right)
        difference = left.bytesize ^ right.to_s.bytesize
        [left.bytesize, right.to_s.bytesize].max.times { |index| difference |= (left.getbyte(index) || 0) ^ (right.to_s.getbyte(index) || 0) }
        difference.zero?
      end
      private_class_method :secure_equal
    end
  end
end
