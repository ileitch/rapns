module Rapns
  module Gcm
    module ActiveRecord
      class Notification < Rapns::ActiveRecord::Notification
        validates :registration_ids, :presence => true
        validates_with Rapns::Gcm::ExpiryCollapseKeyMutualInclusionValidator
        validates_with Rapns::Gcm::PayloadSizeValidator

        def registration_ids=(ids)
          super(Array(ids))
        end

        def as_json
          json = {
            'registration_ids' => registration_ids,
            'delay_while_idle' => delay_while_idle,
            'data' => data
          }

          if collapse_key
            json.merge!({
              'collapse_key' => collapse_key,
              'time_to_live' => expiry
            })
          end

          json
        end
      end
    end
  end
end
