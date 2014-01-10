class CreateAlwaysAllowedSites < ActiveRecord::Migration
  def self.up
    create_table :always_allowed_sites do |t|
      t.string :name
      t.string :detail
      t.timestamps
    end
  end

  def self.down
    drop_table :always_allowed_sites
  end
end
