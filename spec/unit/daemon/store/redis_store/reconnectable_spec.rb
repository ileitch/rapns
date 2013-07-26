require 'unit_spec_helper'
require 'rapns/daemon/store/redis_store/reconnectable'

describe Rapns::Daemon::Store::RedisStore::Reconnectable, mock_redis: true do

  class TestDouble
    include Rapns::Daemon::Store::RedisStore::Reconnectable

    def initialize(error, max_calls)
      @error = error
      @max_calls = max_calls
      @calls = 0
      @counter = 0
    end

    def perform
      with_redis_reconnect_and_retry do
        @calls += 1
        raise @error if @calls <= @max_calls
      end
    end

    def check_redis_is_connected
      #overwrite to simulate the failing of with_redis_reconnect_and_retry 2 times only
      @counter += 1
      case @counter
        when 1
          return false
        when 2
          raise @error
        when 3
          return false
        when 4
          return true
      end
    end
  end

  let(:error) { Redis::CannotConnectError.new("Redis down!") }
  let(:test_double) { TestDouble.new(error, 1) }

  before do
    @logger = mock("Logger", :info => nil, :error => nil, :warn => nil)
    Rapns.stub(:logger).and_return(@logger)
    test_double.redis_connections_pool
    test_double.stub(:sleep)
  end

  it "logs the error raised" do
    Rapns.logger.should_receive(:error).with(error.message)
    test_double.perform
  end

  it "logs that the Redis is being reconnected" do
    Rapns.logger.should_receive(:warn).with("Lost connection to Redis, reconnecting...")
    test_double.perform
  end

  it "logs the reconnection attempt" do
    Rapns.logger.should_receive(:warn).with("Attempt 1")
    test_double.perform
  end

  it "clears all connections" do
    test_double.redis_connections_pool.should_receive(:shutdown)
    test_double.perform
  end

  it "establishes new connections" do
    original_connection = test_double.redis_connections_pool
    test_double.perform
    expect(test_double.redis_connections_pool).to_not eq original_connection
  end

  it "tests the new connections" do
    test_double.should_receive(:check_redis_is_connected).and_return(true)
    test_double.perform
  end

  context "when the reconnection attempt is not successful" do

    it "logs the 2nd attempt" do
      Rapns.logger.should_receive(:warn).with("Attempt 2")
      test_double.perform
    end

    it "logs errors raised when the reconnection is not successful without notifying airbrake" do
      Rapns.logger.should_receive(:error).with(error.message, :airbrake_notify => false)
      test_double.perform
    end

    it "sleeps to avoid thrashing when the database is down" do
      test_double.should_receive(:sleep).with(2)
      test_double.perform
    end
  end

end