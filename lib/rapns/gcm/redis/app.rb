module Rapns
  module Gcm
    module Redis
      class App
        include Rapns::Redis::App

        attribute :auth_key, :string
      end
    end
  end
end
