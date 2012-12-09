module Rapns
  module Apns
    class QueueStatus < ActiveRecord::Base
      self.table_name = 'rapns_queue_statuses'

      attr_accessible :queue, :heart_beat_at, :sent_count, :failed_count

      def self.queue_status(queue)
        QueueStatus.find_or_create_by_queue(queue)
      end

      def self.sent_ok(queue)
        return unless queue
        self.queue_status(queue).increment!(:sent_count)
      end

      def self.sent_failed(queue)
        return unless queue
        self.queue_status(queue).increment!(:failed_count)
      end

      def self.heart_beat(queue)
        return unless queue
        self.queue_status(queue).update_column(:heart_beat_at, Time.new)
      end
    end
  end
end