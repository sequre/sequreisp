class RemoveLanguageIdFromConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :configurations, :language_id
  end

  def self.down
    add_column :configurations, :language_id, :integer
  end
end
