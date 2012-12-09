module Rapns
  module Daemon
    class AppSync
      include InterruptibleSleep

      def initialize(poll = 60)
        @poll = poll
      end

      def start
        @thread = Thread.new do
          loop do
            break if @stop
            interruptible_sleep @poll
            check_for_sync
          end
        end
      end

      def stop
        @stop = true
        interrupt_sleep
        @thread.join if @thread
      end

      def check_for_sync
        Rapns::Daemon.logger.info("[AppSync]")

        QueueStatus.heart_beat(Rapns::Daemon.config.queue)

        AppRunner.sync
      end
    end
  end
end