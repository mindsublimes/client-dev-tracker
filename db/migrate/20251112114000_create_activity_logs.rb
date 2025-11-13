class CreateActivityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_logs do |t|
      t.references :agenda_item, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false
      t.string :field_name
      t.text :previous_value
      t.text :new_value
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :activity_logs, :created_at
  end
end
