class SearchesController < ApplicationController
  layout false

  def index
    @query = params[:q].to_s.strip
    @results = []

    return render plain: '' if @query.blank?

    # Search projects
    project_scope = policy_scope(Project).includes(:client)
    projects = project_scope.where('projects.name ILIKE ? OR projects.description ILIKE ?', "%#{@query}%", "%#{@query}%").limit(5)
    projects.each do |project|
      @results << {
        type: 'project',
        title: project.name,
        subtitle: project.client.name,
        url: project_path(project),
        icon: 'bi-kanban'
      }
    end

    # Search sprints
    sprint_scope = policy_scope(Sprint).includes(project: :client)
    sprints = sprint_scope.where('sprints.name ILIKE ? OR sprints.goal ILIKE ?', "%#{@query}%", "%#{@query}%").limit(5)
    sprints.each do |sprint|
      @results << {
        type: 'sprint',
        title: sprint.name,
        subtitle: sprint.project&.name || 'No project',
        url: sprint_path(sprint),
        icon: 'bi-lightning-charge'
      }
    end

    # Search agenda items
    agenda_scope = policy_scope(AgendaItem).includes(:client, :assignee, :project, :sprint)
    agenda_items = agenda_scope.where('agenda_items.title ILIKE ? OR agenda_items.description ILIKE ?', "%#{@query}%", "%#{@query}%").limit(5)
    agenda_items.each do |item|
      @results << {
        type: 'agenda_item',
        title: item.title,
        subtitle: "#{item.client.name} - #{item.status.titleize}",
        url: agenda_item_path(item),
        icon: 'bi-list-check'
      }
    end

    # Search agenda messages (only from accessible agenda items, excluding own messages)
    accessible_agenda_item_ids = policy_scope(AgendaItem).pluck(:id)
    messages = AgendaMessage.joins(:agenda_item, :user)
                            .where(agenda_item_id: accessible_agenda_item_ids)
                            .where('agenda_messages.body ILIKE ?', "%#{@query}%")
                            .where.not(user_id: current_user.id) # Exclude own messages
                            .limit(5)
    messages.each do |message|
      @results << {
        type: 'message',
        title: message.body.truncate(60),
        subtitle: "#{message.agenda_item.title} - #{message.user.full_name}",
        url: agenda_item_path(message.agenda_item),
        icon: 'bi-chat-dots'
      }
    end

    # Group results by type for better organization
    @grouped_results = @results.group_by { |r| r[:type] }
    @results = @results.first(10)
  end
end

