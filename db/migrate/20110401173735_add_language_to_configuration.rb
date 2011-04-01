class AddLanguageToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :language, :string
  end

  def self.down
    remove_column :configurations, :language
  end
end
