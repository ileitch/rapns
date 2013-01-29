module Rapns
  module Daemon
    module Gcm
      # http://developer.android.com/guide/google/gcm/gcm.html#response
      class Delivery < Rapns::Daemon::Delivery
        include Rapns::MultiJsonHelper

        GCM_URI = URI.parse('https://android.googleapis.com/gcm/send')
        UNAVAILABLE_STATES = ['Unavailable', 'InternalServerError']

        def initialize(app, http, notification)
          @app = app
          @http = http
          @notification = notification
        end

        def perform
          begin
            handle_response(do_post)
          rescue Rapns::DeliveryError => error
            mark_failed(error.code, error.description)
            raise
          end
        end

        protected

        def handle_response(response)
          case response.code.to_i
          when 200
            ok(response)
          when 400
            bad_request(response)
          when 401
            unauthorized(response)
          when 500
            internal_server_error(response)
          when 503
            service_unavailable(response)
          else
            raise Rapns::DeliveryError.new(response.code, @notification.id, HTTP_STATUS_CODES[response.code.to_i])
          end
        end

        def ok(response)
          body = multi_json_load(response.body)

          if body['failure'].to_i == 0
            mark_delivered unless Rapns.config.insane_notify
            Rapns::Daemon.logger.info("[#{@app.name}] #{@notification.id} sent to #{@notification.registration_ids.join(', ')}")
          else
            handle_errors(response, body)
          end
        end

        def handle_errors(response, body)
          errors = {}

          body['results'].each_with_index do |result, i|
            errors[i] = result['error'] if result['error']
          end

          if body['success'].to_i == 0 && errors.values.all? { |error| error.in?(UNAVAILABLE_STATES) }
            all_devices_unavailable(response)
          elsif errors.values.any? { |error| error.in?(UNAVAILABLE_STATES) }
            some_devices_unavailable(response, errors)
          else
            raise Rapns::DeliveryError.new(nil, @notification.id, describe_errors(errors))
          end
        end

        def bad_request(response)
          raise Rapns::DeliveryError.new(400, @notification.id, 'GCM failed to parse the JSON request. Possibly an rapns bug, please open an issue.')
        end

        def unauthorized(response)
          raise Rapns::DeliveryError.new(401, @notification.id, 'Unauthorized, check your App auth_key.')
        end

        def internal_server_error(response)
          retry_delivery(@notification, response)
          Rapns::Daemon.logger.warn("GCM responded with an Internal Error. " + retry_message)
        end

        def service_unavailable(response)
          retry_delivery(@notification, response)
          Rapns::Daemon.logger.warn("GCM responded with an Service Unavailable Error. " + retry_message)
        end

        def all_devices_unavailable(response)
          retry_delivery(@notification, response)
          Rapns::Daemon.logger.warn("All recipients unavailable. " + retry_message)
        end

        def some_devices_unavailable(response, errors)
          unavailable_idxs = errors.find_all { |i, error| error.in?(UNAVAILABLE_STATES) }.map(&:first)
          new_notification = build_new_notification(response, unavailable_idxs)
          with_database_reconnect_and_retry { new_notification.save! }
          raise Rapns::DeliveryError.new(nil, @notification.id,
            describe_errors(errors) + " #{unavailable_idxs.join(', ')} will be retried as notification #{new_notification.id}.")
        end

        def build_new_notification(response, idxs)
          notification = Rapns::Gcm::Notification.new
          notification.assign_attributes(@notification.attributes.slice('app_id', 'collapse_key', 'delay_while_idle'))
          notification.data = @notification.data
          notification.registration_ids = idxs.map { |i| @notification.registration_ids[i] }
          notification.deliver_after = deliver_after_header(response)
          notification
        end

        def deliver_after_header(response)
          if response.header['retry-after']
            retry_after = if response.header['retry-after'].to_s =~ /^[0-9]+$/
              Time.now + response.header['retry-after'].to_i
            else
              Time.httpdate(response.header['retry-after'])
            end
          end
        end

        def retry_delivery(notification, response)
          if time = deliver_after_header(response)
            retry_after(notification, time)
          else
            retry_exponentially(notification)
          end
        end

        def describe_errors(errors)
          description = if errors.size == @notification.registration_ids.size
            "Failed to deliver to all recipients. Errors: #{errors.values.join(', ')}."
          else
            "Failed to deliver to recipients #{errors.keys.join(', ')}. Errors: #{errors.values.join(', ')}."
          end
        end

        def retry_message
          "Notification #{@notification.id} will be retired after #{@notification.deliver_after.strftime("%Y-%m-%d %H:%M:%S")} (retry #{@notification.retries})."
        end

        def do_post
          post = Net::HTTP::Post.new(GCM_URI.path, initheader = {'Content-Type'  => 'application/json',
                                                                 'Authorization' => "key=#{@notification.app.auth_key}"})
          post.body = @notification.as_json.to_json
          @http.request(GCM_URI, post)
        end

        HTTP_STATUS_CODES = {
          100  => 'Continue',
          101  => 'Switching Protocols',
          102  => 'Processing',
          200  => 'OK',
          201  => 'Created',
          202  => 'Accepted',
          203  => 'Non-Authoritative Information',
          204  => 'No Content',
          205  => 'Reset Content',
          206  => 'Partial Content',
          207  => 'Multi-Status',
          226  => 'IM Used',
          300  => 'Multiple Choices',
          301  => 'Moved Permanently',
          302  => 'Found',
          303  => 'See Other',
          304  => 'Not Modified',
          305  => 'Use Proxy',
          306  => 'Reserved',
          307  => 'Temporary Redirect',
          400  => 'Bad Request',
          401  => 'Unauthorized',
          402  => 'Payment Required',
          403  => 'Forbidden',
          404  => 'Not Found',
          405  => 'Method Not Allowed',
          406  => 'Not Acceptable',
          407  => 'Proxy Authentication Required',
          408  => 'Request Timeout',
          409  => 'Conflict',
          410  => 'Gone',
          411  => 'Length Required',
          412  => 'Precondition Failed',
          413  => 'Request Entity Too Large',
          414  => 'Request-URI Too Long',
          415  => 'Unsupported Media Type',
          416  => 'Requested Range Not Satisfiable',
          417  => 'Expectation Failed',
          418  => "I'm a Teapot",
          422  => 'Unprocessable Entity',
          423  => 'Locked',
          424  => 'Failed Dependency',
          426  => 'Upgrade Required',
          500  => 'Internal Server Error',
          501  => 'Not Implemented',
          502  => 'Bad Gateway',
          503  => 'Service Unavailable',
          504  => 'Gateway Timeout',
          505  => 'HTTP Version Not Supported',
          506  => 'Variant Also Negotiates',
          507  => 'Insufficient Storage',
          510  => 'Not Extended',
        }
      end
    end
  end
end
