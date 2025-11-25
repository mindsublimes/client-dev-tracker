class CreateTimeEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :agenda_item, null: false, foreign_key: true
      t.decimal :hours, precision: 10, scale: 2
      t.date :date
      t.text :notes

      t.timestamps
    end
  end
end
