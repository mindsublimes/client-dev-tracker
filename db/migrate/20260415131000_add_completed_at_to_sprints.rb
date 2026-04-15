# frozen_string_literal: true

class AddCompletedAtToSprints < ActiveRecord::Migration[7.1]
  def change
    add_column :sprints, :completed_at, :datetime
    add_index :sprints, :completed_at
  end
end
