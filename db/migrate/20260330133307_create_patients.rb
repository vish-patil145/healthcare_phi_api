class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.string :name
      t.integer :age, limit: 2
      t.string :gender

      t.timestamps
    end
  end
end
