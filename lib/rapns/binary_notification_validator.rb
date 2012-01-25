module Rapns
  class BinaryNotificationValidator < ActiveModel::Validator

    def validate(record)
      if record.payload_size > 256
        record.errors[:base] << "APN notification payload cannot be larger than 256 bytes. Try condensing your alert attribute."
      end
    end
  end
end