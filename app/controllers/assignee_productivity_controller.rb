class AssigneeProductivityController < ApplicationController
  def index
    authorize AgendaItem, :index?

    scope = policy_scope(AgendaItem.includes(:client, :assignee, :project, :sprint))
    
    # Get all unique assignees (including unassigned)
    assignee_ids = scope.distinct.pluck(:assignee_id).compact
    assignees = User.where(id: assignee_ids).order(:first_name, :last_name)
    
    # Build productivity data for each assignee
    @productivity_data = assignees.map do |assignee|
      assignee_items = scope.where(assignee_id: assignee.id)
      all_items = assignee_items.to_a
      
      # Calculate metrics
      total = all_items.size
      completed = all_items.count(&:completed?)
      in_progress = all_items.count(&:in_progress?)
      blocked = all_items.count(&:blocked?)
      backlog = all_items.count { |item| item.backlog? || item.scoped? }
      pending = assignee_items.pending.count
      
      # Rank performance (average rank score of pending items)
      pending_items = assignee_items.pending
      avg_rank = pending_items.any? ? pending_items.average(:rank_score).to_f.round(1) : 0
      
      # Last active (most recent update on any assigned item)
      last_active = assignee_items.maximum(:updated_at)
      
      # Overdue count
      overdue = assignee_items.pending.where('due_on < ?', Date.current).count
      
      # Urgent count
      urgent = assignee_items.pending.where(priority_level: :urgent).count
      
      {
        assignee: assignee,
        name: assignee.full_name,
        total: total,
        completed: completed,
        in_progress: in_progress,
        blocked: blocked,
        backlog: backlog,
        pending: pending,
        overdue: overdue,
        urgent: urgent,
        avg_rank: avg_rank,
        last_active: last_active
      }
    end
    
    # Add unassigned row if there are unassigned items
    unassigned_items = scope.where(assignee_id: nil).to_a
    if unassigned_items.any?
      unassigned_scope = scope.where(assignee_id: nil)
      @productivity_data << {
        assignee: nil,
        name: 'Unassigned',
        total: unassigned_items.size,
        completed: unassigned_items.count(&:completed?),
        in_progress: unassigned_items.count(&:in_progress?),
        blocked: unassigned_items.count(&:blocked?),
        backlog: unassigned_items.count { |item| item.backlog? || item.scoped? },
        pending: unassigned_scope.pending.count,
        overdue: unassigned_scope.pending.where('due_on < ?', Date.current).count,
        urgent: unassigned_scope.pending.where(priority_level: :urgent).count,
        avg_rank: unassigned_scope.pending.any? ? unassigned_scope.pending.average(:rank_score).to_f.round(1) : 0,
        last_active: unassigned_scope.maximum(:updated_at)
      }
    end
    
    # Sort by name
    @productivity_data.sort_by! { |row| row[:name].downcase }
  end
end

