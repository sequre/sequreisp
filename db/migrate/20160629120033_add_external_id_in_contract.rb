class AddExternalIdInContract < ActiveRecord::Migration
  def self.up
    add_column :clients, :external_id, :integer, :index => true
  end

  def self.down
    remove_column :clients, :external_id
  end
end
