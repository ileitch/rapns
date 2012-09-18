class CreateRapnsRemoteSignals < ActiveRecord::Migration
  def self.up
    create_table :rapns_remote_signals do |t|
      t.string    :key,    :null => false
      t.text      :payload,   :null => true
    end
  end

  def self.down
    drop_table :rapns_remote_signals
  end
end
