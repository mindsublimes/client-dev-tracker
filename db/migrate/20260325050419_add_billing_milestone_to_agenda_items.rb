class AddBillingMilestoneToAgendaItems < ActiveRecord::Migration[7.1]
  def change
    add_column :agenda_items, :billing_milestone, :boolean, null: false, default: false
  end
end
