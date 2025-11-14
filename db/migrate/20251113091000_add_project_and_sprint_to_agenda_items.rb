class AddProjectAndSprintToAgendaItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :agenda_items, :project, foreign_key: true
    add_reference :agenda_items, :sprint, foreign_key: true
  end
end
