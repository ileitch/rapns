module Rapns
  module Apns
    class Feedback < Rapns::RecordBase
      if Rapns.config.store == :active_record
        self.table_name = 'rapns_feedback'
      else
        
        field :device_token, type: String
        field :failed_at,    type: DateTime
        
        belongs_to :app, class_name: 'Rapns::App'
        
        index({device_token: 1})
      end
      
      if Rapns.attr_accessible_available?
        attr_accessible :device_token, :failed_at, :app
      end

      validates :device_token, :presence => true
      validates :failed_at, :presence => true

      validates_with Rapns::Apns::DeviceTokenFormatValidator
    end
  end
end
