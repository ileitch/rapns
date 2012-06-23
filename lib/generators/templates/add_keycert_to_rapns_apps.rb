class AddKeyCertToRapnsApps < ActiveRecord::Migration
  def self.up
    add_column :rapns_apps, :keycert, :text, :null => true
  end

  def self.down
    remove_column :rapns_apps, :keycert
  end
end
