class CreateRapnsNotifications < ActiveRecord::Migration
  def self.up
    create_table :rapns_notifications do |t|
      t.integer   :badge,                 :null => true
      t.string    :device_token,          :null => false, :limit => 64
      t.string    :sound,                 :null => true,  :default => "1.aiff"
      t.string    :alert,                 :null => true
      t.integer   :content_available,     :null => false, :default => 0
      t.text      :attributes_for_device, :null => true
      t.integer   :expiry,                :null => false, :default => 1.day.to_i
      t.boolean   :delivered,             :null => false, :default => false
      t.timestamp :delivered_at,          :null => true
      t.boolean   :failed,                :null => false, :default => false
      t.timestamp :failed_at,             :null => true
      t.integer   :error_code,            :null => true
      t.string    :error_description,     :null => true
      t.timestamp :deliver_after,         :null => true
      t.timestamps
    end

    add_index :rapns_notifications, [:delivered, :failed, :deliver_after], :name => "index_rapns_notifications_on_delivered_failed_deliver_after"
  end

  def self.down
    drop_table :rapns_notifications
  end
end
