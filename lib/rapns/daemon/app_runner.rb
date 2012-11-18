module Rapns
  module Daemon
    class AppRunner
      class << self
        attr_reader :runners
      end

      @runners = {}

      def self.deliver(notification)
        if app = runners[notification.app_id]
          app.deliver(notification)
        else
          Rapns::Daemon.logger.error("No such app '#{notification.app_id}' for notification #{notification.id}.")
        end
      end

      def self.sync
        apps = Rapns::App.all
        apps.each { |app| sync_app(app) }
        removed = runners.keys - apps.map(&:id)
        removed.each { |app_id| runners.delete(app_id).stop }
      end

      def self.sync_app(app)
        if runners[app.id]
          runners[app.id].sync(app)
        else
          runner = new_runner(app)
          begin
            runner.start
            runners[app.id] = runner
          rescue StandardError => e
            Rapns::Daemon.logger.error("[#{app.name}] Exception raised during startup. Notifications will not be delivered for this app.")
            Rapns::Daemon.logger.error(e)
          end
        end
      end

      def self.new_runner(app)
        type = app.class.parent.name.demodulize
        "Rapns::Daemon::#{type}::AppRunner".constantize.new(app)
      end

      def self.stop
        @runners.values.map(&:stop)
      end

      def self.debug
        @runners.values.map(&:debug)
      end

      def self.idle
        runners.values.find_all { |runner| runner.idle? }
      end

      attr_reader :app

      def initialize(app)
        @app = app
      end

      def start
        pool
        started
      end

      def stop
        pool.terminate
        stopped
      end

      def deliver(notification)
        pool.async.deliver(notification)
      end

      def sync(app)
        @app = app
        diff = pool.size - app.connections
        diff > 0 ? pool.shrink(diff) : pool.grow(diff.abs)
      end

      def idle?
        pool.mailbox_size == 0
      end

      def debug
        Rapns::Daemon.logger.info <<-EOS
#{@app.name}:
  handlers: #{pool.size}
  backlog: #{pool.mailbox_size}
  idle: #{idle?}
        EOS
      end

      protected

      def pool
        return @pool if defined? @pool
        options = { size: @app.connections }
        options[:args] = delivery_handler_args if delivery_handler_args
        @pool = delivery_handler_class.pool(options)
      end

      def delivery_handler_class
        "#{self.class.parent.name}::DeliveryHandler".constantize
      end

      def delivery_handler_args
      end

      def started
      end

      def stopped
      end
    end
  end
end
