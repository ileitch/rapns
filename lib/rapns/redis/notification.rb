module Rapns
  module Redis
    module Notification
      include Rapns::Redis::KeyHelpers

      def self.included(base)
        base.instance_eval do
          include Modis::Model

          attribute :app_id,            :integer
          attribute :data,              :string
          attribute :delivered,         :boolean, :default => false
          attribute :delivered_at,      :time
          attribute :failed,            :boolean, :default => false
          attribute :failed_at,         :time
          attribute :error_code,        :integer
          attribute :error_description, :string
          attribute :expiry,            :integer, :default => 1.day.to_i
          attribute :deliver_after,     :time
          attribute :retries,           :integer

          # belongs_to :app

          after_create  :track
          after_update  :untrack_if_undelivereable
          after_destroy :untrack
        end
      end

      def track
        key = key_for_undelivered(app)
        Redis.current.sadd(key, id)
      end

      def untrack
        key = key_for_undelivered(app)
        Redis.current.srem(key, id)
      end

      def untrack_if_undelivereable
        if delivered_changed? && delivered == true
          untrack
        elsif failed_changed? && failed == true
          untrack
        end
      end
    end
  end
end
