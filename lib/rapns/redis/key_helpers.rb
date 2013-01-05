module Rapns
  module Redis
    module KeyHelpers
      def key_for_undelivered(app)
        app_type = app.class.name.split('::')[1].downcase
        "rapns:#{app_type}:notification:undelivered:app:#{app.id}"
      end
    end
  end
end
