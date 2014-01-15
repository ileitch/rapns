require 'active_record'

require 'rapns/daemon/store/active_record/lock'
require 'rapns/daemon/store/active_record/reconnectable'

module Rapns
  module Daemon
    module Store
      class ActiveRecord
        include Reconnectable

        DEFAULT_MARK_OPTIONS = {:persist => true}

        def try_lock
          # old_min_id, old_limit = 0

          old_key = Lock.key
          old_min_id, old_limit = Lock.parse_key(old_key)

          relation = deliverable_notifications_relation
          relation = relation.where(['id > ?', old_min_id + old_limit])
          min_id = relation.minimum(:id)

          return false unless min_id

          batch_size = Rapns.config.batch_size
          Lock.try_lock(old_key, Lock.build_key(min_id, batch_size))
        end

        def deliverable_notifications(apps)
          with_database_reconnect_and_retry do
            deliverable_notifications_relation.for_apps(apps).to_a
          end
        end

        # TODO: Make this respect [apps]?
        def deliverable_notifications_relation
          batch_size = Rapns.config.batch_size
          relation = Rapns::Notification.ready_for_delivery
          relation = relation.limit(batch_size) unless Rapns.config.push
          relation
        end

        def mark_retryable(notification, deliver_after, opts = {})
          opts = DEFAULT_MARK_OPTIONS.dup.merge(opts)
          notification.retries += 1
          notification.deliver_after = deliver_after

          if opts[:persist]
            with_database_reconnect_and_retry do
              notification.save!(:validate => false)
            end
          end
        end

        def mark_batch_retryable(notifications, deliver_after)
          ids = []
          notifications.each do |n|
            mark_retryable(n, deliver_after, :persist => false)
            ids << n.id
          end
          with_database_reconnect_and_retry do
            Rapns::Notification.where(:id => ids).update_all(['retries = retries + 1, deliver_after = ?', deliver_after])
          end
        end

        def mark_delivered(notification, time, opts = {})
          opts = DEFAULT_MARK_OPTIONS.dup.merge(opts)
          notification.delivered = true
          notification.delivered_at = time

          if opts[:persist]
            with_database_reconnect_and_retry do
              notification.save!(:validate => false)
            end
          end
        end

        def mark_batch_delivered(notifications)
          now = Time.now
          ids = []
          notifications.each do |n|
            mark_delivered(n, now, :persist => false)
            ids << n.id
          end
          with_database_reconnect_and_retry do
            Rapns::Notification.where(:id => ids).update_all(['delivered = ?, delivered_at = ?', true, now])
          end
        end

        def mark_failed(notification, code, description, time, opts = {})
          opts = DEFAULT_MARK_OPTIONS.dup.merge(opts)
          notification.delivered = false
          notification.delivered_at = nil
          notification.failed = true
          notification.failed_at = time
          notification.error_code = code
          notification.error_description = description

          if opts[:persist]
            with_database_reconnect_and_retry do
              notification.save!(:validate => false)
            end
          end
        end

        def mark_batch_failed(notifications, code, description)
          now = Time.now
          ids = []
          notifications.each do |n|
            mark_failed(n, code, description, now, :persist => false)
            ids << n.id
          end
          with_database_reconnect_and_retry do
            Rapns::Notification.where(:id => ids).update_all(['delivered = ?, delivered_at = NULL, failed = ?, failed_at = ?, error_code = ?, error_description = ?', false, true, now, code, description])
          end
        end

        def create_apns_feedback(failed_at, device_token, app)
          with_database_reconnect_and_retry do
            Rapns::Apns::Feedback.create!(:failed_at => failed_at,
              :device_token => device_token, :app => app)
          end
        end

        def create_gcm_notification(attrs, data, registration_ids, deliver_after, app)
          with_database_reconnect_and_retry do
            notification = Rapns::Gcm::Notification.new
            notification.assign_attributes(attrs)
            notification.data = data
            notification.registration_ids = registration_ids
            notification.deliver_after = deliver_after
            notification.app = app
            notification.save!
            notification
          end
        end

        def create_adm_notification(attrs, data, registration_ids, deliver_after, app)
          with_database_reconnect_and_retry do
            notification = Rapns::Adm::Notification.new
            notification.assign_attributes(attrs)
            notification.data = data
            notification.registration_ids = registration_ids
            notification.deliver_after = deliver_after
            notification.app = app
            notification.save!
            notification
          end
        end

        def update_app(app)
          with_database_reconnect_and_retry do
            app.save!
          end
        end

        def update_notification(notification)
          with_database_reconnect_and_retry do
            notification.save!
          end
        end

        def after_daemonize
          reconnect_database
        end
      end
    end
  end
end
