module Rapns
  module Daemon
    module Apns
      class Delivery < Rapns::Daemon::Delivery
        def initialize(app, conneciton, notification, batch)
          @app = app
          @connection = conneciton
          @notification = notification
          @batch = batch
        end

        def perform
          begin
            @connection.write(@notification.to_binary)
            check_for_error if Rapns.config.check_for_errors
            mark_delivered
            Rapns.logger.info("[#{@app.name}] #{@notification.id} sent to #{@notification.device_token}")
          rescue Rapns::DeliveryError, Rapns::Apns::DisconnectionError => error
            mark_failed(error.code, error.description)
            raise
          end
        end
      end
    end
  end
end
