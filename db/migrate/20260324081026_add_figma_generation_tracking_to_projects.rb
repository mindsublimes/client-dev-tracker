class AddFigmaGenerationTrackingToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :figma_generation_status, :string, null: false, default: "idle"
    add_column :projects, :figma_generation_error, :text
  end
end
