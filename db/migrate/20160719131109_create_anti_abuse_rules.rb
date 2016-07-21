class CreateAntiAbuseRules < ActiveRecord::Migration
  def self.up
    create_table :anti_abuse_rules do |t|
      t.integer :tcp_port
      t.integer :ban_time
      t.integer :trigger_hitcount
      t.integer :trigger_seconds
      t.boolean :log
      t.boolean :enabled
      t.boolean :tcp_syn_flag

      t.timestamps
    end
  end

  def self.down
    drop_table :anti_abuse_rules
  end
end
