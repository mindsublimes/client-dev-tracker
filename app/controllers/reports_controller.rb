class ReportsController < ApplicationController
  def index
    authorize ActivityLog, :index?
    
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    
    # Filter agenda items based on user role (policy_scope handles role-based filtering)
    # Admin sees all, Client sees their items, Developer sees assigned items
    scope = policy_scope(AgendaItem).includes(:client, :assignee, :project, :sprint)
    
    # Items being worked on (in progress, blocked, in review)
    @items_in_progress = scope.where(status: [:in_progress, :blocked, :in_review])
                              .order(due_on: :asc, created_at: :desc)
    
    # Overdue items with days overdue (exclude completed, archived, cancelled)
    @overdue_items = scope.where('due_on < ?', Date.current)
                         .where.not(status: [:completed, :archived, :cancelled])
                         .order(due_on: :asc)
    
    # Calculate days overdue for each item
    @overdue_items_with_days = @overdue_items.map do |item|
      days_overdue = (Date.current - item.due_on).to_i
      { item: item, days_overdue: days_overdue }
    end
    
    # Tasks created vs completed over time (for dual line chart)
    @tasks_created_by_date = {}
    @tasks_completed_by_date = {}
    (@start_date..@end_date).each do |date|
      @tasks_created_by_date[date] = scope.where('DATE(created_at) = ?', date).count
      @tasks_completed_by_date[date] = scope.where('DATE(completed_at) = ?', date).count
    end
    
    # Agenda items by priority (for pie chart) - use all items in scope (current state)
    @items_by_priority = scope.group(:priority_level).count
    
    # Agenda items by status (for horizontal bar chart) - items created in date range
    @items_by_status = scope.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
                            .group(:status)
                            .count
    
    # Total statistics
    @total_items = scope.count
    @total_completed = scope.where(status: :completed).count
    @total_overdue = @overdue_items.count
    @total_in_progress = @items_in_progress.count
    
    # Recent completions (last 7 days)
    @recent_completions = scope.where(status: :completed)
                               .where('completed_at >= ?', 7.days.ago)
                               .order(completed_at: :desc)
                               .limit(10)
  end
end
