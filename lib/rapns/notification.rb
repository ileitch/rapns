module Rapns
  class Notification < Rapns::RecordBase
    include Rapns::MultiJsonHelper

    if Rapns.config.store == :active_record 
      self.table_name = 'rapns_notifications'
      
      scope :ready_for_delivery, lambda {
        where('delivered = ? AND failed = ? AND (deliver_after IS NULL OR deliver_after < ?)',
              false, false, Time.now)
      }
    
      scope :for_apps, lambda { |apps|
        where('app_id IN (?)', apps.map(&:id))
      }
      
      # TODO: Dump using multi json.
      serialize :registration_ids
      
    else
      include Mongoid::Autoinc
      store_in collection: 'rapns_notifications'
      
      field :badge, type: Integer
      field :device_token, type: String
      field :sound, type: String, default: "default"
      field :alert, type: String
      field :data, type: String
      field :expiry, type: Integer, default: 86400
      field :delivered, type: Boolean, default: false
      field :delivered_at, type: DateTime
      field :failed, type: Boolean, default: false
      field :failed_at, type: DateTime
      field :deliver_after, type: DateTime
      field :alert_is_json, type: Boolean, default: false
      field :collapse_key, type: String
      field :delay_while_idle, type: Boolean, default: false
      field :registration_ids, type: Array
      field :app_id, type: Integer
      field :retries, type: Integer, default: 0
      field :error_code, type: Integer
      field :error_description, type: String
      field :validation_id, type: Integer
      
      increments :validation_id
      
      index({app_id: 1, delivered: -1, failed: -1, deliver_after: -1})
      index({delivered: -1, failed: -1, deliver_after: -1})
      
      scope :ready_for_delivery, lambda {
        where({"$and" => [delivered: false, failed: false, "$or" => [{"$deliver_after.ne" => nil}, deliver_after: {"$lt" => Time.now}]]})
      }
    
      scope :for_apps, lambda { |apps|
        where(app_id: {"$in" => apps.map(&:id)})
      }
      
    end

    belongs_to :app, :class_name => 'Rapns::App'

    if Rapns.attr_accessible_available?
      attr_accessible :badge, :device_token, :sound, :alert, :data, :expiry,:delivered,
        :delivered_at, :failed, :failed_at, :error_code, :error_description, :deliver_after,
        :alert_is_json, :app, :app_id, :collapse_key, :delay_while_idle, :registration_ids
    end

    validates :expiry, :numericality => true, :allow_nil => true
    validates :app, :presence => true
    
    def initialize(*args)
      attributes = args.first
      if attributes.is_a?(Hash) && attributes.keys.include?(:attributes_for_device)
        msg = ":attributes_for_device via mass-assignment is deprecated. Use :data or the attributes_for_device= instance method."
        Rapns::Deprecation.warn(msg)
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
