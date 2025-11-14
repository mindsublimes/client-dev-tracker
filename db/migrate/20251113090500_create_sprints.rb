class CreateSprints < ActiveRecord::Migration[7.1]
  def change
    create_table :sprints do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.date :start_date
      t.date :end_date
      t.decimal :cost, precision: 12, scale: 2
      t.text :goal

      t.timestamps
    end

    add_index :sprints, %i[project_id name], unique: true
  end
end
