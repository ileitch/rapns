module Rapns
  module Daemon
    class DeliveryHandler
      attr_accessor :queue

      def deliver(notification)
        raise NotImplementedError
      end

      def start
        @thread = Thread.new do
          loop do
            handle_next_notification
            break if @stop
          end
        end
      end

      def stop
        @stop = true
        if @thread
          queue.wakeup(@thread)
          @thread.join
        end
        stopped
      end

      protected

      def stopped
      end

      def handle_next_notification
        begin
          notification = queue.pop
        rescue DeliveryQueue::WakeupError
          return
        end

        begin
          deliver(notification)
          QueueStatus.sent_ok(Rapns::Daemon.config.queue)
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
          QueueStatus.sent_failed(Rapns::Daemon.config.queue)
        ensure
          queue.notification_processed
        end
      end
    end
  end
end
