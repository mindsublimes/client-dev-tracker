class AddClientLiaisonReportedAtToAgendaItems < ActiveRecord::Migration[7.1]
  def change
    add_column :agenda_items, :client_liaison_reported_at, :datetime
    add_index :agenda_items, :client_liaison_reported_at
  end
end
