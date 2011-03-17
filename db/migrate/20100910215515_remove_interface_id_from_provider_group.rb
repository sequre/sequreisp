class RemoveInterfaceIdFromProviderGroup < ActiveRecord::Migration
  def self.up
    remove_column :provider_groups, :interface_id
  end

  def self.down
    add_column :provider_groups, :interface_id, :integer
  end
end
