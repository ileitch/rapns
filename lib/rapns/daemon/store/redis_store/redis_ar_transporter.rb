module Rapns
  class RedisArTransporter

    KEYS_FOR_IPHONE = [:type, :app_id, :device_token, :alert, :data, :id, :retries, :deliver_after]
    KEYS_FOR_ANDROID = [:type, :app_id, :registration_ids, :data, :id, :retries, :deliver_after]

    RAPNS_TYPE_TO_DEVICE_TYPE = {'Rapns::Apns::Notification' => 'iphone', 'Rapns::Gcm::Notification' => 'android'}

    COUNTER_NAME = 'rapns:notifications:counter'

    def initialize(object)
      object = JSON.parse(object, symbolize_names: true) if object.is_a?(String)
      @object = object
      set_id
    end

    def attributes
      temp_attributes = get_attributes(@object)
      temp_attributes[:type] = RAPNS_TYPE_TO_DEVICE_TYPE.key(temp_attributes[:type])
      temp_attributes[:device_token].gsub!(' ', '') if temp_attributes[:device_token]
      temp_attributes
    end

    def to_s
      attributes.to_json
    end

    def to_ar
      temp_attributes = get_attributes(@object)
      notif = build_rapns_notification(temp_attributes)

      #These attributes cannot be mass assigned
      notif.id = temp_attributes[:id]
      notif.retries = temp_attributes[:retries]
      if temp_attributes[:deliver_after].present?
        if temp_attributes[:deliver_after].is_a?(String)
          notif.deliver_after = Time.parse(temp_attributes[:deliver_after])
        elsif temp_attributes[:deliver_after].is_a?(ActiveSupport::TimeWithZone)
          notif.deliver_after = temp_attributes[:deliver_after]
        end
      end
      notif
    end

    protected

    def build_rapns_notification(attributes_hash)
      if iphone?(attributes_hash[:type])
        Rapns::Apns::Notification.new(attributes_hash)
      else
        Rapns::Gcm::Notification.new(attributes_hash)
      end
    end

    def set_id
      return if @object[:id].present?

      next_id = Redis.current.incr(COUNTER_NAME)
      if @object.is_a?(Hash)
        @object[:id] = next_id
      else
        @object.id = next_id
      end
    end

    def iphone?(type)
      ['iphone', 'Rapns::Apns::Notification'].include?(type)
    end

    def get_attributes(object)
      attributes_hash = {}

      if object.is_a?(ActiveRecord::Base)
        attributes_hash[:type] = RAPNS_TYPE_TO_DEVICE_TYPE[object.type]
        keys = iphone?(attributes_hash[:type]) ? KEYS_FOR_IPHONE : KEYS_FOR_ANDROID
        (keys - [:type]).each do |key|
          attributes_hash[key] = object.send(key)
        end
      else
        attributes_hash = iphone?(object[:type]) ? generate_hash_for_iphone(object) : generate_hash_for_android(object)
      end
      attributes_hash
    end

    def generate_hash_for_iphone(attributes)
      #{type: device.type, app_id: app.id, device_token: device.token, alert: payload[:alert], data: payload[:custom_properties]}
      attributes_hash = {}
      KEYS_FOR_IPHONE.each do |key|
        if key == :data && attributes[:data].blank?
          attributes_hash[key] = attributes[:custom_properties]
        else
          attributes_hash[key] = attributes[key]
        end
      end
      attributes_hash
    end

    def generate_hash_for_android(attributes)
      #{type: device.type, app_id: app.id, registration_ids: [device.token], data: payload[:alert].merge('custom_properties' => payload[:custom_properties])}
      attributes[:alert] = {message: attributes[:alert]} unless attributes[:alert].is_a?(Hash)
      attributes_hash = {}
      KEYS_FOR_ANDROID.each do |key|
        if key == :data && attributes[:data].blank?
          attributes_hash[key] = attributes[:alert].merge('custom_properties' => attributes[:custom_properties])
        else
          attributes_hash[key] = attributes[key]
        end
      end
      attributes_hash
    end
  end

end
