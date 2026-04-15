# frozen_string_literal: true

class AddClientAgentWorkflowFields < ActiveRecord::Migration[7.1]
  def change
    change_table :projects, bulk: true do |t|
      t.datetime :design_payment_received_at
      t.text :wireframe_outline
      t.text :dev_task_spec_markdown
    end

    change_table :sprints, bulk: true do |t|
      t.datetime :development_payment_received_at
      t.boolean :under_client_review, null: false, default: false
      t.text :ai_executive_review
    end

    change_table :agenda_items, bulk: true do |t|
      t.string :figma_screen_url
      t.string :figma_node_id
      t.jsonb :checklist, null: false, default: []
      t.string :agent_source
    end

    create_table :documentation_pages do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body
      t.datetime :generated_at
      t.string :generation_source

      t.timestamps
    end

    add_index :documentation_pages, %i[project_id slug], unique: true
  end
end
