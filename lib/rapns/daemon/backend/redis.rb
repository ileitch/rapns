require 'redis'

require 'rapns/daemon/backend/redis/feeder'

module Rapns
  module Daemon
    module Backend
      class Redis
        class NotConnectedError < StandardError
        end

        attr_reader :feeder

        def initialize
          connect unless ::Redis.current.client.connected?
          @feeder = Feeder.new
        end

        protected

        def connect
          ::Redis.current = ::Redis.new(Rapns.config.redis.to_hash)
          ::Redis.current.client.connect
          if !::Redis.current.client.connected?
            raise NotConnectedError, "Unable to connect to Redis using #{Rapns.config.redis.to_hash.inspect}"
          end
        end
      end
    end
  end
end
