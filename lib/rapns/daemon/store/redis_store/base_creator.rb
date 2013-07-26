module Rapns
  class BaseCreator

    def create(device_type, device_token, payload = {})
      raise "cannot create notification for empty payload" if payload[:alert].blank?
      if transport = build_transport_object(device_type, device_token, payload)
        save_to_store(transport)
      end
    end

    def self.creator
      storage = Rapns.config.store
      "Rapns::#{storage.to_s.camelize}Creator".constantize.new
    end

    protected

    def build_transport_object(device_type, device_token, payload)
      if device_type == "iphone"
        if app = Rapns::Apns::App.last
          RedisArTransporter.new(payload.merge(type: device_type, device_token: device_token, app_id: app.id))
        else
          Airbrake.notify(ActiveRecord::RecordNotFound.new("No Rapns::Apns::App found. Please run rake mobile:create_default_apps."))
          return nil
        end
      else
        if app = Rapns::Gcm::App.last
          RedisArTransporter.new(payload.merge(type: device_type, registration_ids: [device_token], app_id: app.id))
        else
          Airbrake.notify(ActiveRecord::RecordNotFound.new("No Rapns::Gcm::App found. Please run rake mobile:create_default_apps."))
          return nil
        end
      end
    end

    def save_to_store(transport)
      raise "BaseCreator#save_to_store is a virtual method"
    end

  end
end
