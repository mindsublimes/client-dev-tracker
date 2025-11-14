class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.date :start_date
      t.date :end_date
      t.decimal :estimated_cost, precision: 12, scale: 2
      t.text :description

      t.timestamps
    end

    add_index :projects, %i[client_id name], unique: true
  end
end
