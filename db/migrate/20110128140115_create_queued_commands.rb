class CreateQueuedCommands < ActiveRecord::Migration
  def self.up
    create_table :queued_commands do |t|
      t.text :command
      t.boolean :executed, :default => false

      t.timestamps
    end
  end

  def self.down
    drop_table :queued_commands
  end
end
