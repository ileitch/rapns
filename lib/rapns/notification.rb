module Rapns
  class Notification < ActiveRecord::Base
    include Rapns::MultiJsonHelper

    self.table_name = 'rapns_notifications'

    # TODO: Dump using multi json.
    serialize :registration_ids

    belongs_to :app, :class_name => 'Rapns::App'

    attr_accessible :badge, :device_token, :sound, :alert, :data, :expiry,:delivered,
      :delivered_at, :failed, :failed_at, :error_code, :error_description, :deliver_after,
      :alert_is_json, :app, :app_id, :collapse_key, :delay_while_idle, :registration_ids

    validates :expiry, :numericality => true, :allow_nil => true
    validates :app, :presence => true

    scope :ready_for_delivery, lambda {
      where('delivered = ? AND failed = ? AND (deliver_after IS NULL OR deliver_after < ?)',
            false, false, Time.now)
    }

    scope :for_apps, lambda { |apps|
      where(:app_id => apps.map(&:id))
    }

    scope :for_queue, lambda { |queue|
      where(:queue => queue)
    }
    
    def initialize(attributes = nil, options = {})
      if attributes.is_a?(Hash) && attributes.keys.include?(:attributes_for_device)
        msg = ":attributes_for_device via mass-assignment is deprecated. Use :data or the attributes_for_device= instance method."
        ActiveSupport::Deprecation.warn(msg, caller(1))
      end
      super
    end

    def data=(attrs)
      return unless attrs
      raise ArgumentError, "must be a Hash" if !attrs.is_a?(Hash)
      write_attribute(:data, multi_json_dump(attrs))
    end

    def data
      multi_json_load(read_attribute(:data)) if read_attribute(:data)
    end

    def payload
      multi_json_dump(as_json)
    end

    def payload_size
      payload.bytesize
    end
  end
end
