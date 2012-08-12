class CreateRapnsRemoteSignals < ActiveRecord::Migration
  def self.up
    create_table :rapns_signals do |t|
      t.string    :signal,    :null => false
      t.text      :payload,   :null => true
    end
  end

  def self.down
    drop_table :rapns_signals
  end
end
