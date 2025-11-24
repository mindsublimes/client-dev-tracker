class CalendarsController < ApplicationController
  before_action :set_clients, only: [:index]

  def index
    authorize AgendaItem, :index?

    @filters = filter_params
    @view_type = params[:view] || 'calendar' # 'calendar' or 'gantt'
    
    # Parse month/year from params or use current
    @current_month = params[:month]&.to_i || Date.current.month
    @current_year = params[:year]&.to_i || Date.current.year
    @current_date = Date.new(@current_year, @current_month, 1)

    # Build scope for agenda items
    scope = policy_scope(AgendaItem.includes(:client, :assignee, :project, :sprint))
    
    # Apply filters
    scope = scope.where(client_id: @filters[:client_id]) if @filters[:client_id].present?
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?
    scope = scope.where(work_stream: @filters[:work_stream]) if @filters[:work_stream].present?
    scope = scope.where(assignee_id: @filters[:assignee_id]) if @filters[:assignee_id].present?
    
    if @filters[:search].present?
      query = "%#{@filters[:search]}%"
      scope = scope.where('title ILIKE :query OR requested_by ILIKE :query', query:)
    end

    # For calendar view: get items that have due dates or started dates in the month
    if @view_type == 'calendar'
      start_of_month = @current_date.beginning_of_month
      end_of_month = @current_date.end_of_month
      
      # Get items that have due dates or started dates in the month
      # Items without dates won't show in calendar (they need at least a due_on or started_on)
      @agenda_items = scope.where(
        '(due_on BETWEEN ? AND ?) OR (started_on BETWEEN ? AND ?)',
        start_of_month, end_of_month, start_of_month, end_of_month
      ).order(:due_on, :started_on)
      
      # Group by date for calendar display
      @items_by_date = @agenda_items.group_by do |item|
        item.due_on || item.started_on || start_of_month
      end
      
      # Build calendar grid
      @calendar_start = @current_date.beginning_of_week(:sunday)
      @calendar_end = @current_date.end_of_month.end_of_week(:sunday)
      @calendar_days = (@calendar_start..@calendar_end).to_a
    else
      # For gantt view: get all items with dates
      @agenda_items = scope.where.not(due_on: nil).or(
        scope.where.not(started_on: nil)
      ).order(:started_on, :due_on)
      
      # Group by project and sprint for gantt
      @items_by_project = @agenda_items.group_by(&:project).sort_by { |project, _| project&.name || 'Unassigned' }
      @items_by_sprint = @agenda_items.group_by(&:sprint).sort_by { |sprint, _| sprint&.name || 'Unassigned' }
    end
  end

  private

  def set_clients
    if current_user&.client? && current_user.client.present?
      @clients = [current_user.client]
      @assignees = []
    else
      @clients = policy_scope(Client).ordered
      @assignees = User.active.order(:first_name, :last_name)
    end
  end

  def filter_params
    permitted = params.fetch(:filters, {}).permit(:client_id, :status, :work_stream, :assignee_id, :search).to_h

    filters = {
      client_id: permitted['client_id'].presence&.to_i,
      status: permitted['status'].presence,
      work_stream: permitted['work_stream'].presence,
      assignee_id: permitted['assignee_id'].presence&.to_i,
      search: permitted['search'].presence
    }

    if current_user&.client? && current_user.client_id.present?
      filters[:client_id] = current_user.client_id
    end

    # Remove nil values for URL parameters
    filters.compact
  end
end

