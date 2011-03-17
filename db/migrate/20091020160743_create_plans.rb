class CreatePlans < ActiveRecord::Migration
  def self.up
    create_table :plans do |t|
      t.string :name
      t.integer :provider_group_id
      t.integer :rate_down
      t.integer :ceil_down
      t.integer :rate_up
      t.integer :ceil_up
      t.integer :periodicity

      t.timestamps
    end
  end

  def self.down
    drop_table :plans
  end
end
