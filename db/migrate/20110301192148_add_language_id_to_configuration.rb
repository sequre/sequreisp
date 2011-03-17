class AddLanguageIdToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :language_id, :integer
  end

  def self.down
    remove_column :configurations, :language_id
  end
end
