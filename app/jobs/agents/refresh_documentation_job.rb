# frozen_string_literal: true

module Agents
  class RefreshDocumentationJob < ApplicationJob
    queue_as :default

    def perform(project_id: nil)
      scope = project_id.present? ? Project.where(id: project_id) : Project.all
      scope.find_each do |project|
        begin
          Agents::DocumentationGenerator.call(project: project)
        rescue StandardError => e
          Rails.logger.error("[Agents::RefreshDocumentationJob] project=#{project.id} #{e.class}: #{e.message}")
        end
      end
    end
  end
end
