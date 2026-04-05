class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.integer :user_id
      t.string :action
      t.string :record_type
      t.integer :record_id

      t.timestamps
    end
  end
end
