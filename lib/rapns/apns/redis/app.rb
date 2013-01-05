module Rapns
  module Apns
    module Redis
      class App
        include Modis::Model

        attribute :environment, :string
        attribute :certificate, :string
        attribute :password,    :string
      end
    end
  end
end
