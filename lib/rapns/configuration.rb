module Rapns
  def self.config
    @config ||= Rapns::Configuration.new
  end

  def self.configure
    yield config if block_given?
  end

  CONFIG_ATTRS = [:foreground, :push_poll, :feedback_poll, :embedded,
    :airbrake_notify, :check_for_errors, :pid_file, :batch_size,
    :push, :backend]
  REDIS_CONFIG_ATTRS = [:host, :port, :path, :driver]
  AR_CONFIG_ATTRS = [:host, :port, :username, :password, :adapter, :database,
    :encoding, :database_yml]

  class HashableStruct < Struct
    def to_hash
      Hash[members.zip(values)]
    end
  end

  class ConfigurationWithoutDefaults < HashableStruct.new(*CONFIG_ATTRS)
  end

  class RedisConfiguration < HashableStruct.new(*REDIS_CONFIG_ATTRS)
  end

  class ActiveRecordConfiguration < HashableStruct.new(*AR_CONFIG_ATTRS)
  end

  class Configuration < HashableStruct.new(*CONFIG_ATTRS)
    include Deprecatable

    attr_accessor :apns_feedback_callback

    def initialize
      super
      set_defaults
    end

    def update(other)
      CONFIG_ATTRS.each do |attr|
        other_value = other.send(attr)
        send("#{attr}=", other_value) unless other_value.nil?
      end
    end

    def pid_file=(path)
      if path && !Pathname.new(path).absolute?
        super(File.join(Rails.root, path))
      else
        super
      end
    end

    def redis
      @redis ||= RedisConfiguration.new
      block_given? ? yield(@redis) : @redis
    end

    def active_record
      @active_record ||= ActiveRecordConfiguration.new
      block_given? ? yield(@active_record) : @active_record
    end

    def on_apns_feedback(&block)
      self.apns_feedback_callback = block
    end
    deprecated(:on_apns_feedback, 3.2, "Please use the Rapns.reflect API instead.")

    private

    def set_defaults
      self.foreground = false
      self.push_poll = 2
      self.feedback_poll = 60
      self.airbrake_notify = true
      self.check_for_errors = true
      self.batch_size = 5000
      self.pid_file = nil
      self.apns_feedback_callback = nil
      self.backend = :active_record

      # Internal options.
      self.embedded = false
      self.push = false
    end
  end
end
