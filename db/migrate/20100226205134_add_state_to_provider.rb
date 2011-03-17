class AddStateToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :state, :string
  end

  def self.down
    remove_column :providers, :state
  end
end
