module Rapns
  def self.config
    @config ||= Rapns::Configuration.new
  end

  def self.configure
    yield config if block_given?
  end

  CONFIG_ATTRS = [:foreground, :push_poll, :feedback_poll, :embedded,
    :airbrake_notify, :check_for_errors, :pid_file, :batch_size,
    :push, :store, :logger, :redis_host, :redis_port,
    :number_of_connections, :connection_timeout, :stalled_notification_tolerence]

  class ConfigurationWithoutDefaults < Struct.new(*CONFIG_ATTRS)
  end

  class Configuration < Struct.new(*CONFIG_ATTRS)
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

    def logger=(logger)
      super(logger)
    end

    def foreground=(bool)
      if Rapns.jruby?
        # The JVM does not support fork().
        super(true)
      else
        super
      end
    end

    def on_apns_feedback(&block)
      self.apns_feedback_callback = block
    end
    deprecated(:on_apns_feedback, 3.2, "Please use the Rapns.reflect API instead.")

    def set_defaults
      if Rapns.jruby?
        # The JVM does not support fork().
        self.foreground = true
      else
        self.foreground = false
      end

      self.push_poll = 2
      self.feedback_poll = 60
      self.airbrake_notify = true
      self.check_for_errors = true
      self.batch_size = 5000
      self.pid_file = nil
      self.apns_feedback_callback = nil
      self.store = :active_record
      self.logger = nil

      # Internal options.
      self.embedded = false
      self.push = false

      # Redis store
      self.redis_host = "localhost"
      self.redis_port = 6793
      self.number_of_connections = 5
      self.connection_timeout = 1
      self.stalled_notification_tolerence = 3600
    end
  end
end
