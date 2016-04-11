module Rapns
  module Apns
    class BinaryNotificationValidator < ActiveModel::Validator
      MAX_BYTES = 2048

      def validate(record)
        if record.payload_size > MAX_BYTES
          record.errors[:base] << "APN notification cannot be larger than #{MAX_BYTES} bytes. Try condensing your alert and device attributes."
        end
      end
    end
  end
end
