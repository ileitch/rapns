require 'thread'
require 'socket'
require 'pathname'
require 'openssl'

require 'net/http/persistent'

require 'rapns/daemon/interruptible_sleep'
require 'rapns/daemon/delivery_error'
require 'rapns/daemon/database_reconnectable'
require 'rapns/daemon/delivery'
require 'rapns/daemon/delivery_queue'
require 'rapns/daemon/feeder'
require 'rapns/daemon/logger'
require 'rapns/daemon/app_runner'
require 'rapns/daemon/delivery_handler'

require 'rapns/daemon/apns/delivery'
require 'rapns/daemon/apns/disconnection_error'
require 'rapns/daemon/apns/connection'
require 'rapns/daemon/apns/app_runner'
require 'rapns/daemon/apns/delivery_handler'
require 'rapns/daemon/apns/feedback_receiver'

require 'rapns/daemon/gcm/delivery'
require 'rapns/daemon/gcm/app_runner'
require 'rapns/daemon/gcm/delivery_handler'

module Rapns
  module Daemon
    extend DatabaseReconnectable

    class << self
      attr_accessor :logger, :config
    end

    def self.start(config)
      self.config = config
      self.logger = Logger.new(:foreground => config.foreground, :airbrake_notify => config.airbrake_notify)
      setup_signal_hooks

      unless config.foreground
        daemonize
        reconnect_database
      end

      write_pid_file
      ensure_upgraded
      AppRunner.sync

      @app_sync = AppSync.new
      @app_sync.start

      Feeder.start(config.push_poll)
    end

    protected

    def self.ensure_upgraded
      count = 0

      begin
        count = Rapns::App.count
      rescue ActiveRecord::StatementInvalid
        puts "!!!! RAPNS NOT STARTED !!!!"
        puts
        puts "As of version v2.0.0 apps are configured in the database instead of rapns.yml."
        puts "Please run 'rails g rapns' to generate the new migrations and create your apps with Rapns::App."
        puts "See https://github.com/ileitch/rapns for further instructions."
        puts
        exit 1
      end

      if count == 0
        logger.warn("You have not created an Rapns::App yet. See https://github.com/ileitch/rapns for instructions.")
      end

      if File.exists?(File.join(Rails.root, 'config', 'rapns', 'rapns.yml'))
        logger.warn("Since 2.0.0 rapns uses command-line options instead of a configuration file. Please remove config/rapns/rapns.yml.")
      end
    end

    def self.setup_signal_hooks
      @shutting_down = false

      Signal.trap('SIGHUP') { AppRunner.sync }
      Signal.trap('SIGUSR1') { AppRunner.debug }

      ['SIGINT', 'SIGTERM'].each do |signal|
        Signal.trap(signal) { handle_shutdown_signal }
      end
    end

    def self.handle_shutdown_signal
      exit 1 if @shutting_down
      @shutting_down = true
      shutdown
    end

    def self.shutdown
      puts "\nShutting down..."
      Feeder.stop
      AppRunner.stop

      @app_sync.stop

      delete_pid_file
    end

    def self.write_pid_file
      if !config.pid_file.blank?
        begin
          File.open(config.pid_file, 'w') { |f| f.puts Process.pid }
        rescue SystemCallError => e
          logger.error("Failed to write PID to '#{config.pid_file}': #{e.inspect}")
        end
      end
    end

    def self.delete_pid_file
      pid_file = config.pid_file
      File.delete(pid_file) if !pid_file.blank? && File.exists?(pid_file)
    end

    # :nocov:
    def self.daemonize
      exit if pid = fork
      Process.setsid
      exit if pid = fork

      Dir.chdir '/'
      File.umask 0000

      STDIN.reopen '/dev/null'
      STDOUT.reopen '/dev/null', 'a'
      STDERR.reopen STDOUT
    end
  end
end
