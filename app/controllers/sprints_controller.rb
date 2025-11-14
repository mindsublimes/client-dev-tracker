class SprintsController < ApplicationController
  before_action :set_sprint

  def show
    authorize @sprint

    @agenda_items = @sprint.agenda_items.includes(:assignee)
    @sprint_stats = build_sprint_stats(@agenda_items)
    @assignee_breakdown = build_assignee_breakdown(@agenda_items)
  end

  private

  def set_sprint
    @sprint = policy_scope(Sprint).includes(project: :client).find(params[:id])
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
