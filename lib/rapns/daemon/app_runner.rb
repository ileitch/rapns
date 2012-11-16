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
        apps.each do |app|
          if runners[app.id]
            runners[app.id].sync(app)
          else
            runner = new_runner(app)
            begin
              runner.start
              runners[app.id] = runner
            rescue StandardError => e
              Rapns::Daemon.logger.error("[App:#{app.name}] failed to start. No notifications will be sent.")
              Rapns::Daemon.logger.error(e)
            end
          end
        end

        removed = runners.keys - apps.map(&:id)
        removed.each { |app_id| runners.delete(app_id).stop }
      end

      def self.new_runner(app)
        "#{app.class.parent.name}::AppRunner".constantize
      end

      def self.stop
        @runners.values.map(&:stop)
      end

      def self.debug
        @runners.values.map(&:debug)
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
        pool.async.deliver(notification) if ready?
      end

      def sync(app)
        @app = app
        diff = pool.size - app.connections
        diff > 0 ? pool.shrink(diff) : pool.grow(diff.abs)
      end

      def debug
        Rapns::Daemon.logger.info("\nApp State:\n#{@app.name}:\n  handlers: #{pool.size}\n  backlog: #{pool.mailbox_size}\n  ready: #{ready?}")
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

      def ready?
        pool.mailbox_size == 0
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
