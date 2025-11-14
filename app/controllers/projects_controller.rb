class ProjectsController < ApplicationController
  before_action :set_project

  def show
    authorize @project

    @sprints = @project.sprints.includes(agenda_items: :assignee).order(:start_date)
    @agenda_items = @project.agenda_items.includes(:sprint)

    @project_stats = build_project_stats(@agenda_items)
    @sprint_summaries = build_sprint_summaries(@sprints)
  end

  private

  def set_project
    @project = policy_scope(Project).includes(:client).find(params[:id])
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
