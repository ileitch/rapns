module Rapns
  module Gcm
    module Redis
      class Notification
        include Rapns::Redis::Notification

        attribute :registration_ids, :array
        attribute :delay_while_idle, :boolean
        attribute :collapse_key, :string
      end
    end
  end
end
