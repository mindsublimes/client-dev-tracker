module AgendaItemsHelper
  def sprint_options_for_select(sprints, selected_id)
    options = sprints.map do |sprint|
      [sprint.label, sprint.id, { 'data-client-id': sprint.project.client_id, 'data-project-id': sprint.project_id }]
    end

    options_for_select(options, selected_id)
  end
end
