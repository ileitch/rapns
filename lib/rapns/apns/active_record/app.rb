module Rapns
  module Apns
    module ActiveRecord
      class App < Rapns::ActiveRecord::App
        validates :environment, :presence => true, :inclusion => { :in => %w(development production) }
        validates :certificate, :presence => true
      end
    end
  end
end
