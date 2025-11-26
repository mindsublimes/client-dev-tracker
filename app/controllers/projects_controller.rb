class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update]
  before_action :set_form_collections, only: %i[new create edit update]

  def index
    authorize Project

    scope = policy_scope(Project).includes(:client)
    @filters = project_filter_params

    # For developers, only show projects associated with agenda items they're assigned to
    if current_user&.developer?
      assigned_project_ids = AgendaItem.where(assignee_id: current_user.id)
                                       .where.not(project_id: nil)
                                       .distinct
                                       .pluck(:project_id)
      scope = scope.where(id: assigned_project_ids)
    end

    scope = scope.where(client_id: @filters[:client_id]) if @filters[:client_id].present?
    if @filters[:search].present?
      term = "%#{@filters[:search]}%"
      scope = scope.where('projects.name ILIKE :term OR projects.description ILIKE :term', term:)
    end

    @projects = scope.order(created_at: :desc)
    @clients = clients_for_filter
  end

  def show
    authorize @project

    @sprints = @project.sprints.includes(agenda_items: :assignee).order(:start_date)
    @agenda_items = @project.agenda_items.includes(:sprint)

    @project_stats = build_project_stats(@agenda_items)
    @sprint_summaries = build_sprint_summaries(@sprints)
  end

  def new
    @project = Project.new(start_date: Date.current, end_date: Date.current + 30.days)
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    if @project.save
      redirect_to @project, success: 'Project created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project

    if @project.update(project_params)
      redirect_to @project, success: 'Project updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = policy_scope(Project).includes(:client).find(params[:id])
  end

  def set_form_collections
    @clients = policy_scope(Client).ordered
  end

  def project_params
    params.require(:project).permit(:client_id, :name, :description, :estimated_cost, :start_date, :end_date)
  end

  def project_filter_params
    permitted = params.fetch(:filters, {}).permit(:client_id, :search)
    {
      client_id: permitted[:client_id].presence&.to_i,
      search: permitted[:search].presence
    }
  end

  def clients_for_filter
    if current_user&.client? && current_user.client.present?
      [current_user.client]
    else
      policy_scope(Client).ordered
    end
  end

  def build_project_stats(items)
    items = items.to_a
    total = items.size
    completed = items.select(&:completed?).size
    in_progress = items.select(&:in_progress?).size
    blocked = items.select(&:blocked?).size
    overdue = items.select(&:due_on).select { |item| item.due_on < Date.current && !item.completed? }.size

    {
      total: total,
      completed: completed,
      in_progress: in_progress,
      blocked: blocked,
      overdue: overdue,
      progress: percentage(completed, total)
    }
  end

  def build_sprint_summaries(sprints)
    sprints.map do |sprint|
      items = sprint.agenda_items.to_a
      total = items.size
      completed = items.select(&:completed?).size
      in_progress = items.select(&:in_progress?).size

      {
        sprint: sprint,
        total: total,
        completed: completed,
        in_progress: in_progress,
        blocked: items.select(&:blocked?).size,
        progress: percentage(completed, total)
      }
    end
  end

  def percentage(part, total)
    return 0 if total.to_i.zero?

    ((part.to_f / total) * 100).round
  end
end
