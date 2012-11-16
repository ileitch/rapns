module Rapns
  module Daemon
    module Gcm
      class AppRunner < Rapns::Daemon::AppRunner
        def delivery_handler_args
          [app]
        end
      end
    end
  end
end
