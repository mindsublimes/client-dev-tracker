class CreateAgendaMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :agenda_messages do |t|
      t.references :agenda_item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.integer :kind, null: false, default: 0

      t.timestamps
    end
  end
end
