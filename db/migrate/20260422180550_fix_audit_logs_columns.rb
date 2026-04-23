class FixAuditLogsColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :audit_logs, :record_type, :resource
    rename_column :audit_logs, :record_id,   :resource_id

    add_column :audit_logs, :patient_id,  :bigint
    add_column :audit_logs, :ip_address,  :string
    add_column :audit_logs, :metadata,    :jsonb, default: {}
    add_column :audit_logs, :occurred_at, :datetime

    add_index :audit_logs, :patient_id
    add_index :audit_logs, :occurred_at
  end
end
