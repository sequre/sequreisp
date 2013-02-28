class AddAttributeUseExternalNumberClientInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :use_external_number_client, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :use_external_number_client
  end
end
