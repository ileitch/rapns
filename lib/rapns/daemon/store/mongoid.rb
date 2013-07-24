require 'mongoid'

module Rapns
  module Daemon
    module Store
      class Mongoid
        
        def deliverable_notifications(apps)
          batch_size = Rapns.config.batch_size
          relation = Rapns::Notification.ready_for_delivery.for_apps(apps)
          relation = relation.limit(batch_size) unless Rapns.config.push
          relation.to_a
        end

        def retry_after(notification, deliver_after)
          notification.retries += 1
          notification.deliver_after = deliver_after
          notification.save!(:validate => false)
        end

        def mark_delivered(notification)
          notification.delivered = true
          notification.delivered_at = Time.now
          notification.save!(:validate => false)
        end

        def mark_failed(notification, code, description)
          notification.delivered = false
          notification.delivered_at = nil
          notification.failed = true
          notification.failed_at = Time.now
          notification.error_code = code
          notification.error_description = description
          notification.save!(:validate => false)
        end

        def create_apns_feedback(failed_at, device_token, app)
          Rapns::Apns::Feedback.create!(:failed_at => failed_at,
              :device_token => device_token, :app => app)
        end

        def create_gcm_notification(attrs, data, registration_ids, deliver_after, app)
          notification = Rapns::Gcm::Notification.new
          notification.assign_attributes(attrs)
          notification.data = data
          notification.registration_ids = registration_ids
          notification.deliver_after = deliver_after
          notification.app = app
          notification.save!
          notification
        end

        def after_daemonize

        end

      end
    end
  end
end
