class AddMdmsupportToRapnsNotifications < ActiveRecord::Migration
  def self.up
    add_column :rapns_notifications, :mdm, :string, :null => true
  end

  def self.down
    remove_column :rapns_notifications, :mdm
  end
end