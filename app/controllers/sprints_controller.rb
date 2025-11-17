class SprintsController < ApplicationController
  before_action :set_sprint, only: %i[show edit update]
  before_action :set_projects, only: %i[new create edit update]

  def index
    authorize Sprint
    @sprints = policy_scope(Sprint).includes(project: :client).order(:start_date)
  end

  def show
    authorize @sprint

    @agenda_items = @sprint.agenda_items.includes(:assignee)
    @sprint_stats = build_sprint_stats(@agenda_items)
    @assignee_breakdown = build_assignee_breakdown(@agenda_items)
  end

  def new
    @sprint = Sprint.new(start_date: Date.current, end_date: Date.current + 14.days)
    authorize @sprint
  end

  def create
    @sprint = Sprint.new(sprint_params)
    authorize @sprint

    if @sprint.save
      redirect_to @sprint, success: 'Sprint created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @sprint
  end

  def update
    authorize @sprint

    if @sprint.update(sprint_params)
      redirect_to @sprint, success: 'Sprint updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_sprint
    @sprint = policy_scope(Sprint).includes(project: :client).find(params[:id])
  end

  def set_projects
    @projects = policy_scope(Project).includes(:client).order(:name)
  end

  def sprint_params
    params.require(:sprint).permit(:project_id, :name, :goal, :start_date, :end_date, :cost)
  end

  def build_sprint_stats(items)
    items = items.to_a
    total = items.size
    completed = items.select(&:completed?).size
    in_progress = items.select(&:in_progress?).size
    blocked = items.select(&:blocked?).size
    backlog = items.select { |item| item.backlog? || item.scoped? }.size

    {
      total: total,
      completed: completed,
      in_progress: in_progress,
      blocked: blocked,
      backlog: backlog,
      progress: percentage(completed, total)
    }
  end

  def build_assignee_breakdown(items)
    grouped = items.group_by(&:assignee)
    grouped.map do |assignee, assigned_items|
      {
        name: assignee&.full_name || 'Unassigned',
        total: assigned_items.size,
        in_progress: assigned_items.count(&:in_progress?),
        completed: assigned_items.count(&:completed?),
        backlog: assigned_items.count { |item| item.backlog? || item.scoped? },
        blocked: assigned_items.count(&:blocked?)
      }
    end.sort_by { |entry| entry[:name].downcase }
  end

  def percentage(part, total)
    return 0 if total.to_i.zero?

    ((part.to_f / total) * 100).round
  end
end
