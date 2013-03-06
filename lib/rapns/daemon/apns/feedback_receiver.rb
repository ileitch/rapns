module Rapns
  module Daemon
    module Apns
      class FeedbackReceiver
        include Reflectable
        include InterruptibleSleep
        include DatabaseReconnectable

        FEEDBACK_TUPLE_BYTES = 38

        def initialize(app, host, port, poll)
          @app = app
          @host = host
          @port = port
          @poll = poll
          @certificate = app.certificate
          @password = app.password
        end

        def start
          @thread = Thread.new(@poll) do |poll|
            loop do
              check_for_feedback
              sleep poll
            end
          end
        end

        def stop
          @thread.exit if @thread && @thread.alive?
        end

        def check_for_feedback
          connection = nil
          begin
            connection = Connection.new(@app, @host, @port)
            connection.connect

            while tuple = connection.read(FEEDBACK_TUPLE_BYTES)
              timestamp, device_token = parse_tuple(tuple)
              create_feedback(timestamp, device_token)
            end
          rescue StandardError => e
            Rapns::Daemon.logger.error(e)
          ensure
            connection.close if connection
          end
        end

        protected

        def parse_tuple(tuple)
          failed_at, _, device_token = tuple.unpack("N1n1H*")
          [Time.at(failed_at).utc, device_token]
        end

        def create_feedback(failed_at, device_token)
          formatted_failed_at = failed_at.strftime("%Y-%m-%d %H:%M:%S UTC")
          with_database_reconnect_and_retry do
            Rapns::Daemon.logger.info("[#{@app.name}] [FeedbackReceiver] Delivery failed at #{formatted_failed_at} for #{device_token}.")
            feedback = Rapns::Apns::Feedback.create!(:failed_at => failed_at, :device_token => device_token, :app => @app)
            reflect(:apns_feedback, feedback)

            # Deprecated.
            begin
              Rapns.config.apns_feedback_callback.call(feedback) if Rapns.config.apns_feedback_callback
            rescue StandardError => e
              Rapns::Daemon.logger.error(e)
            end
          end
        end
      end
    end
  end
end
