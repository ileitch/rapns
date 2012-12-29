module Rapns
  module Daemon
    class ActiveRecord
      class Feeder
        include Reconnectable

        def each_notification(apps)
          with_database_reconnect_and_retry do
            batch_size = Rapns.config.batch_size
            relation = Rapns::Notification.ready_for_delivery.for_apps(apps)
            relation = relation.limit(batch_size) unless Rapns.config.push
            relation.each { |notification| yield(notification) }
          end
        end
      end
    end
  end
end
