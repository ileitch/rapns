module Rapns
  module Daemon
    class DeliveryHandler
      include Celluloid

      trap_exit :handle_exit

      def deliver(notification)
        raise NotImplementedError
      end

      def finalize
      end

      def handle_exit(actor, reason)
        Rapns::Daemon.logger.error(reason)
      end
    end
  end
end
