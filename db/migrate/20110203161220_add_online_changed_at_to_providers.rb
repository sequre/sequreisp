class AddOnlineChangedAtToProviders < ActiveRecord::Migration
  def self.up
    add_column :providers, :online_changed_at, :timestamp
    Provider.update_all({:online_changed_at => DateTime.now.utc }, "online_changed_at is NULL")
  end

  def self.down
    remove_column :providers, :online_changed_at
  end
end
