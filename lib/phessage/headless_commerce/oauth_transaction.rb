require 'base64'
require 'digest'
require 'securerandom'

module Phessage
  module HeadlessCommerce
    class OAuthTransaction
      attr_reader :state, :code_verifier, :code_challenge

      def initialize(state:, code_verifier:, code_challenge:)
        @state = state
        @code_verifier = code_verifier
        @code_challenge = code_challenge
        freeze
      end

      def self.create
        verifier = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
        new(
          state: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
          code_verifier: verifier,
          code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
        )
      end
    end
  end
end
