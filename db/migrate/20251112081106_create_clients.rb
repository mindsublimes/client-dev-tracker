class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :contact_name
      t.string :contact_email
      t.integer :priority_level, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :timezone, null: false, default: 'UTC'
      t.text :notes

      t.timestamps
    end

    add_index :clients, :code, unique: true
  end
end
