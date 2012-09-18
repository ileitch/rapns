module Rapns
  class RemoteSignal < ActiveRecord::Base
    self.table_name = 'rapns_remote_signals'

    validates :key, :presence => true

    # returns the next signal
    def self.pop

        signal = nil

        transaction do
          signal = Rapns::RemoteSignal.first
          signal.destroy unless signal.nil?
        end

        signal
    end

    def self.push(options = {})
      remoteSignal = Rapns::RemoteSignal.new()
      remoteSignal.key = options[:key]
      remoteSignal.payload = options[:payload] if options[:payload]
      remoteSignal.save!
    end
  end
end
