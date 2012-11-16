module Rapns
  module Daemon
    module Apns
      class DeliveryHandler < Rapns::Daemon::DeliveryHandler
        attr_reader :name

        def initialize(app, host, port)
          @name = "DeliveryHandler:#{app.name}"
          @connection = Connection.new(@name, host, port, app.certificate, app.password)
          @connection.connect
        end

        def deliver(notification)
          Rapns::Daemon::Apns::Delivery.perform(@connection, notification)
        end

        def finalize
          @connection.close
        end
      end
    end
  end
end
