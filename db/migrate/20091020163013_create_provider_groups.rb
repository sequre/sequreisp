class CreateProviderGroups < ActiveRecord::Migration
  def self.up
    create_table :provider_groups do |t|
      t.string :name
      t.integer :interface_id

      t.timestamps
    end
  end

  def self.down
    drop_table :provider_groups
  end
end
