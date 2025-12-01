class CreateInstructions < ActiveRecord::Migration[7.1]
  def change
    create_table :instructions do |t|
      t.string :title
      t.text :description
      t.references :page, null: false, foreign_key: true
      t.jsonb :dots_data, default: [], null: false

      t.timestamps
    end
  end
end
