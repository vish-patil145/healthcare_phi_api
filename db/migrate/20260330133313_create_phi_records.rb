class CreatePhiRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :phi_records do |t|
      t.references :patient, null: false, foreign_key: true
      t.text       :encrypted_data,    null: false
      t.string     :status,            null: false, default: "pending"
      t.string     :request_id,        null: false
      t.string     :record_type,       null: false, default: "general"
      t.references :created_by,        foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :phi_records, :request_id, unique: true
    add_index :phi_records, :status
  end
end
