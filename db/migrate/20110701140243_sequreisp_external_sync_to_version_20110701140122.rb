class SequreispExternalSyncToVersion20110701140122 < ActiveRecord::Migration
  def self.up
    Engines.plugins["sequreisp_external_sync"].migrate(20110701140122)
  end

  def self.down
    Engines.plugins["sequreisp_external_sync"].migrate(0)
  end
end
