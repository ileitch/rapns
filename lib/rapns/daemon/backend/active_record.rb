require 'active_record'

require 'rapns/daemon/backend/active_record/reconnectable'
require 'rapns/daemon/backend/active_record/feeder'

module Rapns
  module Daemon
    module Backend
      class ActiveRecord
        include Reconnectable

        attr_reader :feeder

        def initialize(config = {})
          @feeder = Feeder.new
        end

        def retry_after(notification, deliver_after)
          with_database_reconnect_and_retry do
            notification.retries += 1
            notification.deliver_after = deliver_after
            notification.save!(:validate => false)
          end
        end

        def mark_delivered(notification)
          with_database_reconnect_and_retry do
            notification.delivered = true
            notification.delivered_at = Time.now
            notification.save!(:validate => false)
          end
        end

        def mark_failed(notification, code, description)
          with_database_reconnect_and_retry do
            notification.delivered = false
            notification.delivered_at = nil
            notification.failed = true
            notification.failed_at = Time.now
            notification.error_code = code
            notification.error_description = description
            notification.save!(:validate => false)
          end
        end

        def create_apns_feedback(failed_at, device_token, app)
          with_database_reconnect_and_retry do
            Rapns::Apns::Feedback.create!(:failed_at => failed_at,
              :device_token => device_token, :app => app)
          end
        end

        def create_gcm_notification(attrs, data, registration_ids, deliver_after)
          with_database_reconnect_and_retry do
            notification = Rapns::Gcm::Notification.new
            notification.assign_attributes(attrs)
            notification.data = data
            notification.registration_ids = registration_ids
            notification.deliver_after = deliver_after
            notification.save!
            notification
          end
        end
      end
    end
  end
end
