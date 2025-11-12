class CreateAgendaItems < ActiveRecord::Migration[7.1]
  def change
    create_table :agenda_items do |t|
      t.references :client, null: false, foreign_key: true
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.integer :work_stream, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :priority_level, null: false, default: 1
      t.integer :complexity, null: false, default: 3
      t.date :due_on
      t.date :started_on
      t.datetime :completed_at
      t.decimal :estimated_cost, precision: 12, scale: 2
      t.boolean :paid, null: false, default: false
      t.string :requested_by
      t.string :requested_by_email
      t.text :notes
      t.integer :rank_score, null: false, default: 0
      t.jsonb :rank_breakdown, null: false, default: {}
      t.datetime :last_ranked_at

      t.timestamps
    end

    add_index :agenda_items, :priority_level
    add_index :agenda_items, :status
    add_index :agenda_items, :due_on
    add_index :agenda_items, :rank_score
    add_index :agenda_items, :work_stream
  end
end
