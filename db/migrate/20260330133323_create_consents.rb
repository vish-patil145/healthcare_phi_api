class CreateConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :consents do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :granted_to
      t.boolean :granted

      t.timestamps
    end
  end
end
