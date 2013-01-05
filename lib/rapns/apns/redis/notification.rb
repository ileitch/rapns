module Rapns
  module Apns
    module Redis
      class Notification
        include Rapns::Redis::Notification

        attribute :device_token,      :string
        attribute :badge,             :integer
        attribute :sound,             :string,  :default => 'default' # TODO: Is this valid?
        attribute :alert,             :string
        attribute :mdm,               :boolean, :default => false
        attribute :content_available, :boolean, :default => false
        attribute :alert_is_json,     :boolean

        alias_method :attributes_for_device, :data
        alias_method :attributes_for_device=, :data=
      end
    end
  end
end
