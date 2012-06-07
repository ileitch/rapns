class AddCertnameToRapnsNotifications < ActiveRecord::Migration
  def self.up
    add_column :rapns_notifications, :cert_common, :string, :default => "default"
  end

  def self.down
    remove_column :rapns_notifications, :cert_common
  end
end