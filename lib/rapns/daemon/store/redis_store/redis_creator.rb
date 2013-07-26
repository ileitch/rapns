require 'rapns/daemon/store/redis_store/base_creator'
require 'rapns/daemon/store/redis_store'

module Rapns
  class RedisCreator < BaseCreator

    NOTIFICATION_QUEUE = Rapns::Daemon::Store::RedisStore::PENDING_QUEUE_NAME

    protected

    def save_to_store(transport)
      Redis.current.rpush NOTIFICATION_QUEUE, transport
      transport.attributes
    end

  end
end
