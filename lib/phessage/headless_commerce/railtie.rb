module Phessage;module HeadlessCommerce
 class Railtie<Rails::Railtie
  initializer 'phessage.headless_commerce' do
   ActiveSupport::Notifications.instrument('headless_commerce.loaded',sdk:'ruby') if defined?(ActiveSupport::Notifications)
  end
 end
end;end
