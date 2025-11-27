class ReportsController < ApplicationController
  def index
    authorize ActivityLog, :index?
    
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    
    scope = ActivityLog.includes(:agenda_item, :user)
                      .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
    
    if current_user&.client?
      scope = scope.joins(:agenda_item).where(agenda_items: { client_id: current_user.client_id })
    elsif current_user&.developer?
      scope = scope.joins(:agenda_item).where(agenda_items: { assignee_id: current_user.id })
    end
    
    all_logs = scope.to_a
    @activity_logs = all_logs.sort_by { |log| log.created_at }.reverse
    
    @daily_activity = all_logs.group_by { |log| log.created_at.to_date }
    
    @total_activities = all_logs.count
    @total_agenda_items = all_logs.map(&:agenda_item_id).uniq.count
    @total_users = all_logs.map(&:user_id).compact.uniq.count
    
    activity_types = all_logs.group_by do |log|
      if log.action == 'Agenda item created'
        'Item Created'
      elsif log.field_name == 'status'
        'Status Change'
      elsif log.action&.include?('added') || log.field_name == 'message'
        'Message Posted'
      elsif log.field_name.present?
        'Field Updated'
      else
        'Other Activity'
      end
    end
    @activity_by_type = activity_types.transform_values(&:count)
    
    user_activities = all_logs.select { |log| log.user.present? }
                              .group_by { |log| log.user.full_name }
                              .transform_values(&:count)
    @activity_by_user = user_activities
    
    @status_changes = all_logs.count { |log| log.field_name == 'status' }
    
    @messages_posted = all_logs.count { |log| log.action&.include?('added') }
    
    @items_completed = all_logs.count { |log| log.field_name == 'status' && log.new_value&.include?('Completed') }
    
    @items_created = all_logs.count { |log| log.action == 'Agenda item created' }
    
    @daily_breakdown = {}
    (@start_date..@end_date).each do |date|
      day_logs = @daily_activity[date] || []
      @daily_breakdown[date] = {
        total: day_logs.count,
        status_changes: day_logs.count { |l| l.field_name == 'status' },
        messages: day_logs.count { |l| l.action&.include?('added') },
        completions: day_logs.count { |l| l.field_name == 'status' && l.new_value&.include?('Completed') },
        creations: day_logs.count { |l| l.action == 'Agenda item created' }
      }
    end
  end
end
