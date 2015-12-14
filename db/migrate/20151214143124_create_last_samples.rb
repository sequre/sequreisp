class CreateLastSamples < ActiveRecord::Migration
  def self.up
    create_table :last_samples do |t|
      t.string :model_type
      t.integer :model_id
      t.integer :period
      t.integer :sample_number
      t.timestamps
    end

    add_index :last_samples, :model_id
    add_index :last_samples, :period
  end

  def self.down
    drop_table :last_samples
  end
end
