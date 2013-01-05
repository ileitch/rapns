module Rapns
  module Redis
    module App
      def self.included(base)
        base.instance_eval do
          include Modis::Model

          attribute :name,        :string
          attribute :connections, :integer
        end
      end
    end
  end
end
