class CreateContractSamples < ActiveRecord::Migration
  def self.up
    create_table :contract_samples do |t|
      t.integer  :down_prio1, :default => 0
      t.integer  :down_prio2, :default => 0
      t.integer  :down_prio3, :default => 0
      t.integer  :up_prio1, :default => 0
      t.integer  :up_prio2, :default => 0
      t.integer  :up_prio3, :default => 0
      t.integer  :period
      t.datetime :sample_time
      t.string   :sample_number
      t.integer  :contract_id
      t.timestamps
    end
  end

  def self.down
    drop_table :contract_samples
  end
end
