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
          break if @stop
          process_pending_signals
          enqueue_notifications
          interruptible_sleep poll
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
            ready_apps = Rapns::Daemon::AppRunner.ready
            batch_size = Rapns::Daemon.config.batch_size
            Rapns::Notification.ready_for_delivery.find_each(:batch_size => batch_size) do |notification|
              Rapns::Daemon::AppRunner.deliver(notification) if ready_apps.include?(notification.app)
            end
          end
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        end
      end

      def self.process_pending_signals
        begin
          with_database_reconnect_and_retry do
            loop do
              signal = Rapns::RemoteSignal.pop
              break if signal.nil?

              case signal.key.to_sym
                when :hup then Rapns::Daemon::AppRunner.sync
                else Rapns::Daemon.logger.info("[RemoteSignal] Unknown singal received #{signal.key} (ignoring) ")
              end
            end
          end
        rescue StandardError => e
          Rapns::Daemon.logger.error(e)
        end
      end
    end
  end
end