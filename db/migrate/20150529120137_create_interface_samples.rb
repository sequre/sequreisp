class CreateInterfaceSamples < ActiveRecord::Migration
  def self.up
    create_table :interface_samples do |t|
      t.integer  :rx
      t.integer  :tx
      t.integer  :period
      t.datetime :sample_time
      t.string   :sample_number
      t.integer  :interface_id
      t.timestamps
    end
  end

  def self.down
    drop_table :interface_samples
  end
end
