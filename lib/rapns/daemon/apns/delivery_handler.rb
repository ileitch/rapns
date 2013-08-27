module Rapns
  module Daemon
    module Apns
      class DeliveryHandler < Rapns::Daemon::DeliveryHandler
        HOSTS = {
          :production  => ['gateway.push.apple.com', 2195],
          :development => ['gateway.sandbox.push.apple.com', 2195], # deprecated
          :sandbox     => ['gateway.sandbox.push.apple.com', 2195]
        }

        SELECT_TIMEOUT = 0.2
        ERROR_TUPLE_BYTES = 6
        APN_ERRORS = {
          1 => "Processing error",
          2 => "Missing device token",
          3 => "Missing topic",
          4 => "Missing payload",
          5 => "Missing token size",
          6 => "Missing topic size",
          7 => "Missing payload size",
          8 => "Invalid token",
          255 => "None (unknown error)"
        }

        def initialize(app)
          @app = app
          @host, @port = HOSTS[@app.environment.to_sym]
        end

        def deliver(notification, batch)
          Rapns::Daemon::Apns::Delivery.new(@app, connection, notification, batch).perform
        end

        def stopped
          @connection.close if @connection
        end

        protected

        def connection
          return @connection if defined? @connection
          connection = Connection.new(@app, @host, @port)
          connection.connect
          start_error_receiver
          @connection = connection
        end

        def start_error_receiver
          Thread.new do
            loop do
              check_for_error
            end
          end
        end

        def check_for_error
          if connection.select(SELECT_TIMEOUT)
            error = nil

            if tuple = connection.read(ERROR_TUPLE_BYTES)
              cmd, code, notification_id = tuple.unpack("ccN")

              description = APN_ERRORS[code.to_i] || "Unknown error. Possible rapns bug?"
              error = Rapns::DeliveryError.new(code, notification_id, description)
            else
              error = Rapns::Apns::DisconnectionError.new
            end

            Rapns.logger.error(error)

            # begin
            #   Rapns.logger.error("[#{@app.name}] Error received, reconnecting...")
            #   connection.reconnect
            # ensure
            #   raise error if error
            # end
          end
        end
      end
    end
  end
end
