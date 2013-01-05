module Rapns
  module Apns
    module Redis
      class Feedback
        include Modis::Model

        attribute :device_token, :string
        attribute :failed_at, :time
        attribute :app_id, :integer

        # belongs_to :app
      end
    end
  end
end
