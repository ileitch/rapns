module Rapns
  module Daemon
    class DeliveryQueue
      class WakeupError < StandardError; end

      def initialize
        @mutex = Mutex.new
        @num_notifications = 0
        @queue = []
        @waiting = []

        if Rapns::Daemon.config.extra_debug
          Rapns::Daemon.logger.info("New DeliveryQueue created.")
        end
      end

      def push(notification)
        if Rapns::Daemon.config.extra_debug
          Rapns::Daemon.logger.info("DeliveryQueue.push called with notification: #{notification}")
        end

        @mutex.synchronize do
          @num_notifications += 1
          @queue.push(notification)
          
          if Rapns::Daemon.config.extra_debug
            Rapns::Daemon.logger.info("[push] @waiting.count: #{@waiting.count}")
          end

          begin
            t = @waiting.shift
            if t 
              if Rapns::Daemon.config.extra_debug
                Rapns::Daemon.logger.info("[push] waiting thread.status: #{t.status}")
              end

              t.wakeup
            end
          rescue ThreadError
            if Rapns::Daemon.config.extra_debug
              Rapns::Daemon.logger.info("ThreadError. Retrying.")
            end

            retry
          end
        end
      end

      def pop
        if Rapns::Daemon.config.extra_debug
          Rapns::Daemon.logger.info("DeliveryQueue.pop called.")
        end

        @mutex.synchronize do
          while true
            if Rapns::Daemon.config.extra_debug
              Rapns::Daemon.logger.info("[pop] @waiting.count: #{@waiting.count}")
            end

            if @queue.empty?
              @waiting.push Thread.current
              if Rapns::Daemon.config.extra_debug
                Rapns::Daemon.logger.info("[pop] Thread sleeping.")
              end

              @mutex.sleep

              if Rapns::Daemon.config.extra_debug
                Rapns::Daemon.logger.info("[pop] Thread awake.")
              end
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
