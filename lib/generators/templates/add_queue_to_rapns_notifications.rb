class AddQueueToRapnsNotifications < ActiveRecord::Migration
  def self.up
    add_column :rapns_notifications, :queue, :boolean, :null => true
  end

  def self.down
    remove_column :rapns_notifications, :queue
  end
end