module Rapns
  class Signal < ActiveRecord::Base
    self.table_name = 'rapns_signals'

    attr_accessible :signal, :payload

    validates :signal, :presence => true

    # returns the next signal
    def self.pop
        transaction do
          signal = Signal.first
          signal.destroy unless signal.nil?
        end

        signal || nil
    end
  end
end
