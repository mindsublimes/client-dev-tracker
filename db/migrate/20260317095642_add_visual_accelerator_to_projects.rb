class AddVisualAcceleratorToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :design_brief, :text
    add_column :projects, :design_prompt, :text
    add_column :projects, :generated_design_url, :string
  end
end
