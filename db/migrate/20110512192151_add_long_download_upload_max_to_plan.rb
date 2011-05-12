class AddLongDownloadUploadMaxToPlan < ActiveRecord::Migration
  def self.up
    add_column :plans, :long_download_max, :integer, :default => 0
    add_column :plans, :long_upload_max, :integer, :default => 0
  end

  def self.down
    remove_column :plans, :long_upload_max
    remove_column :plans, :long_download_max
  end
end
