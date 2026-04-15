class CreateClientStatusDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :client_status_deliveries do |t|
      t.references :client, null: false, foreign_key: true
      t.string :status, null: false, default: "sent"
      t.datetime :sent_at, null: false
      t.integer :completed_items_count, null: false, default: 0
      t.text :summary
      t.integer :webhook_response_code
      t.text :error_message
      t.text :payload_json

      t.timestamps
    end

    add_index :client_status_deliveries, :sent_at
    add_index :client_status_deliveries, :status
  end
end
