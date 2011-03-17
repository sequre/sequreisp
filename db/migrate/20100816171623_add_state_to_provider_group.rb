class AddStateToProviderGroup < ActiveRecord::Migration
  def self.up
    add_column :provider_groups, :state, :string
  end

  def self.down
    remove_column :provider_groups, :state
  end
end
