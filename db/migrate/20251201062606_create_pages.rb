class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages do |t|
      t.string :title
      t.string :url
      t.text :description
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
