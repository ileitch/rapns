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

  def self.require_for_daemon
    require 'rapns/daemon'
    require 'rapns/patches'
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
  require 'rapns/notification'
  require 'rapns/app'

  require 'rapns/apns/notification'
  require 'rapns/apns/feedback'
  require 'rapns/apns/app'

  require 'rapns/gcm/notification'
  require 'rapns/gcm/app'
end

if defined? Redis
  require 'rapns/redis/key_helpers'
  require 'rapns/redis/app'
  require 'rapns/redis/notification'

  require 'rapns/apns/redis/notification'
  require 'rapns/apns/redis/feedback'
  require 'rapns/apns/redis/app'

  require 'rapns/gcm/redis/notification'
  require 'rapns/gcm/redis/app'
end
