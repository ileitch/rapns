module Rapns
  module Daemon
    class Feeder
      extend InterruptibleSleep
      extend DatabaseReconnectable

      def self.name
        'Feeder'
      end

      def self.start(poll)
        loop do
          enqueue_notifications
          interruptible_sleep poll
          break if @stop
        end
      end

      def self.stop
        @stop = true
        interrupt_sleep
      end

      protected

      def self.enqueue_notifications
        begin
          with_database_reconnect_and_retry do
            batch_size = Rapns::Daemon.config.batch_size
            idle = Rapns::Daemon::AppRunner.idle.map(&:app)
            queue = Rapns::Daemon.config.queue

            source = Rapns::Notification.ready_for_delivery.for_apps(idle).limit(batch_size)
            source = source.for_queue(queue) if queue

            source.each do |notification|
              Rapns::Daemon::AppRunner.enqueue(notification)
            end
          end
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        end
      end
    end
  end
end
