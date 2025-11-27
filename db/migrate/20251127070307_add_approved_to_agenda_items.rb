class AddApprovedToAgendaItems < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:agenda_items, :approved)
      add_column :agenda_items, :approved, :boolean, default: false, null: false
    else
      # Column exists, just ensure it has the right default
      change_column_default :agenda_items, :approved, false
      change_column_null :agenda_items, :approved, false
    end
  end
end
