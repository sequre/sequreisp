class AddExternalIdInContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :external_id, :integer, :index => true
  end

  def self.down
    remove_column :contracts, :external_id
  end
end
