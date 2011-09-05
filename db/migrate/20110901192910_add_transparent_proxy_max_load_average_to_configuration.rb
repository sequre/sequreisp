class AddTransparentProxyMaxLoadAverageToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :transparent_proxy_max_load_average, :integer, :default => 20
  end

  def self.down
    remove_column :configurations, :transparent_proxy_max_load_average
  end
end
