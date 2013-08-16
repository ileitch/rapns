module Rapns
  module Daemon
    module Store
      class RedisStore
        module Reconnectable

          def with_redis_reconnect_and_retry
            begin
              redis_connections_pool.with do |redis|
                yield redis
              end
            rescue Redis::CannotConnectError => e
              Rapns.logger.error(e.message)
              redis_connection_lost
              retry
            end
          end

          def redis_connection_lost
            Rapns.logger.warn("Lost connection to Redis, reconnecting...")
            attempts = 0
            loop do
              Rapns.logger.warn("Attempt #{attempts += 1}")
              begin
                break if check_redis_is_connected
                reconnect_redis
                check_redis_is_connected
                break
              rescue Redis::CannotConnectError => e
                Rapns.logger.error(e.message, :airbrake_notify => false)
                sleep_to_avoid_thrashing
              end
            end
            Rapns.logger.warn("Redis reconnected")
          end

          def reconnect_redis
            disconnect_redis
            connect_redis
          end

          def check_redis_is_connected
            'PONG' == redis_connections_pool.with do |redis|
              redis.ping
            end
          end

          def sleep_to_avoid_thrashing
            sleep 2
          end

          def redis_connections_pool
            @redis_connections_pool || connect_redis
          end

          protected

          def disconnect_redis
            if @redis_connections_pool
              @redis_connections_pool.shutdown { |redis| redis.quit }
              @redis_connections_pool = nil
            end
          end

          def connect_redis
            @redis_connections_pool = ConnectionPool.new(size: Rapns.config.number_of_connections, timeout: Rapns.config.connection_timeout) { build_redis_connection }
          end

          def build_redis_connection
            Redis.new({host: Rapns.config.redis_host, port: Rapns.config.redis_port})
          end

        end
      end
    end
  end
end