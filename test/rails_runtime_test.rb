require 'rails'
require 'active_support/notifications'
require_relative '../lib/phessage/headless_commerce'

events = []
subscription = nil
begin
  subscription = ActiveSupport::Notifications.subscribe('headless_commerce.loaded') { |*args| events << ActiveSupport::Notifications::Event.new(*args) }
  Class.new(Rails::Application) do
    config.eager_load = false
    config.secret_key_base = 'test-secret-key-base'
  end.initialize!
  raise 'Railtie initializer did not execute' unless events.one? && events.first.payload[:sdk] == 'ruby'
  client = Phessage::HeadlessCommerce::Client.new(base_url: 'https://sandbox.test', publishable_key: 'pk_test_demo', transport: ->(*) { [200, '{"data":[],"requestId":"rails"}'] })
  raise 'Rails runtime could not resolve SDK client' unless client.categories['requestId'] == 'rails'
  puts "Rails #{Rails.version} runtime gate passed"
ensure
  ActiveSupport::Notifications.unsubscribe(subscription) if subscription
end
