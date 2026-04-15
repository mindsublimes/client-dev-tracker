class AddFigmaFileKeyToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :figma_file_key, :string
  end
end
