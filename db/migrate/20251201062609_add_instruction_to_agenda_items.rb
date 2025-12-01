class AddInstructionToAgendaItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :agenda_items, :instruction, null: true, foreign_key: true
  end
end
