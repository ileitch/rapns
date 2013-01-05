module Rapns
  module Daemon
    class Redis
      include Rapns::Redis::KeyHelpers

      # Undelivered notifications are tracked in sets whose key consists of
      # their service type and app ID. For example:
      # rapns:<apns|gcm>:notification:undelivered:app:<app id>
      #
      class Feeder
        APP_TO_NOTIFICATION = {
          Rapns::Apns::Redis::App => Rapns::Apns::Redis::Notification,
          Rapns::Gcm::Redis::App  => Rapns::Apns::Gcm::Notification,
        }

        def each_notification(apps)
          keys = keys_for(app)
          futures = {}

          Redis.current.pipelined do
            keys.each do |key|
              futures[key] = Redis.current.smembers(key)
            end
          end

          futures.each do |key, future|
            notification_class = keys[key]
            future.value.each do |id|
              notification = notification_class.find(id)
              next if notification.deliver_after && notification.deliver_after > Time.now
              yield notification
            end
          end
        end

        protected

        def keys_for(apps)
          apps.inject({}) do |keys, app|
            keys[key_for_undelivered(app)] = APP_TO_NOTIFICATION[app.class]
            keys
          end
        end
      end
    end
  end
end
