require 'multi_json'
require 'active_support'

begin
  require 'active_record'
rescue LoadError
end

begin
  require 'redis'
rescue LoadError
end

module Rapns
  def self.jruby?
    defined? JRUBY_VERSION
  end
end

require 'rapns/version'
require 'rapns/deprecation'
require 'rapns/deprecatable'
require 'rapns/multi_json_helper'
require 'rapns/configuration'
require 'rapns/reflection'
require 'rapns/embed'
require 'rapns/push'

require 'rapns/apns/binary_notification_validator'
require 'rapns/apns/device_token_format_validator'
require 'rapns/apns/required_fields_validator'

require 'rapns/gcm/expiry_collapse_key_mutual_inclusion_validator'
require 'rapns/gcm/payload_size_validator'

if defined? ActiveRecord
  require 'rapns/active_record/notification'
  require 'rapns/active_record/app'

  require 'rapns/apns/active_record/notification'
  require 'rapns/apns/active_record/feedback'
  require 'rapns/apns/active_record/app'

  require 'rapns/gcm/active_record/notification'
  require 'rapns/gcm/active_record/app'

  # Backwards compatibility with 3.1.
  Rapns::App = Rapns::ActiveRecord::App
  Rapns::Notification = Rapns::ActiveRecord::Notification

  Rapns::Apns::Notification = Rapns::Apns::ActiveRecord::Notification
  Rapns::Apns::Feedback = Rapns::Apns::ActiveRecord::Feedback
  Rapns::Apns::App = Rapns::Apns::ActiveRecord::App

  Rapns::Gcm::Notification = Rapns::Gcm::ActiveRecord::Notification
  Rapns::Gcm::App = Rapns::Gcm::ActiveRecord::App
end

# if defined? Redis
#   require 'rapns/redis/notification'
#   require 'rapns/redis/app'

#   require 'rapns/apns/redis/notification'
#   require 'rapns/apns/redis/feedback'
#   require 'rapns/apns/redis/app'

#   require 'rapns/gcm/redis/notification'
#   require 'rapns/gcm/redis/app'
# end
