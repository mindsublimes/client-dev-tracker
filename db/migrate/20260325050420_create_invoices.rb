class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.references :client, null: false, foreign_key: true
      t.references :agenda_item, null: false, foreign_key: true, index: { unique: true }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :status, null: false, default: "open"
      t.string :external_provider, null: false, default: "none"
      t.string :external_id
      t.string :external_url
      t.integer :reminder_stage, null: false, default: 0
      t.datetime :issued_at, null: false
      t.datetime :paid_at
      t.datetime :last_reminder_sent_at
      t.text :sync_error
      t.string :currency, null: false, default: "USD"

      t.timestamps
    end

    add_index :invoices, :status
    add_index :invoices, :issued_at
  end
end
