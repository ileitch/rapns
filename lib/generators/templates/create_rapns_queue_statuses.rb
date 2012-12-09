class CreateRapnsQueueStatuses < ActiveRecord::Migration
  def self.up
    create_table :rapns_queue_statuses do |t|
      t.string    :queue,             :null => false
      t.datetime  :heart_beat_at,     :null => true
      t.integer   :sent_count,        :null => true, :default => 1
      t.integer   :failed_count,      :null => true, :default => 1
      t.timestamps
    end

    add_index :rapns_queue_statuses, :queue, :unique => true
  end

  def self.down
    drop_table :rapns_queue_statuses
  end
end
