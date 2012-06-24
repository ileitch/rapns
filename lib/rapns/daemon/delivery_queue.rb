module Rapns
  module Daemon
    class DeliveryQueue
      class WakeupError < StandardError; end

      def initialize
        @mutex = Mutex.new
        @num_notifications = 0
        @queue = []
        @waiting = []

        Rapns::Daemon.logger.debug("New DeliveryQueue created.")
      end

      def push(notification)
        Rapns::Daemon.logger.debug("DeliveryQueue.push called with notification: #{notification}")

        @mutex.synchronize do
          @num_notifications += 1
          @queue.push(notification)
          
          Rapns::Daemon.logger.debug("[push] @waiting.count: #{@waiting.count}")

          begin
            t = @waiting.shift
            if t 
              Rapns::Daemon.logger.debug("[push] waiting thread.status: #{t.status}")

              t.wakeup
            end
          rescue ThreadError
            Rapns::Daemon.logger.debug("[push] ThreadError. Retrying.")

            retry
          end
        end
      end

      def pop
        Rapns::Daemon.logger.debug("DeliveryQueue.pop called.")

        @mutex.synchronize do
          while true
            Rapns::Daemon.logger.debug("[pop] @waiting.count: #{@waiting.count}")

            if @queue.empty?
              @waiting.push Thread.current
              Rapns::Daemon.logger.debug("[pop] Thread sleeping.")
              @mutex.sleep
              Rapns::Daemon.logger.debug("[pop] Thread awake.")
            else
              return @queue.shift
            end
          end
        end
      end

      def wakeup(thread)
        @mutex.synchronize do
          t = @waiting.delete(thread)
          t.raise WakeupError if t
        end
      end

      def size
        @mutex.synchronize { @queue.size }
      end

      def notification_processed
        @mutex.synchronize { @num_notifications -= 1 }
      end

      def notifications_processed?
        @mutex.synchronize { @num_notifications == 0 }
      end
    end
  end
end
