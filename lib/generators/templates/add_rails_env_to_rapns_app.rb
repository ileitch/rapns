class AddRailsEnvToRapnsApp < ActiveRecord::Migration
  def self.up
    add_column :rapns_apps, :rails_env, :string
  end

  def self.down
    remove_column :rapns_apps, :rails_env
  end
end