module Rapns
  module Gcm
    module ActiveRecord
      class App < Rapns::ActiveRecord::App
        validates :auth_key, :presence => true
      end
    end
  end
end
