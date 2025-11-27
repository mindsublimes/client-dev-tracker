class AgendaItemsController < ApplicationController
  before_action :set_clients, only: %i[index new create edit update new_bulk create_bulk]
  before_action :set_agenda_item, only: %i[show edit update destroy complete reopen rank approve]

  def index
    authorize AgendaItem

    scope = policy_scope(AgendaItem.includes(:client, :assignee, :project, :sprint))
    @filters = filter_params

    scope = scope.where(client_id: @filters[:client_id]) if @filters[:client_id].present?
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?
    scope = scope.where(work_stream: @filters[:work_stream]) if @filters[:work_stream].present?
    if @filters[:search].present?
      query = "%#{@filters[:search]}%"
      scope = scope.where('title ILIKE :query OR requested_by ILIKE :query', query:)
    end

    # Date range filtering
    if @filters[:date_from].present? && @filters[:date_to].present?
      date_from = Date.parse(@filters[:date_from])
      date_to = Date.parse(@filters[:date_to])
      
      case @filters[:date_type]
      when 'created'
        scope = scope.where(created_at: date_from.beginning_of_day..date_to.end_of_day)
      when 'completed'
        scope = scope.where(completed_at: date_from.beginning_of_day..date_to.end_of_day)
      when 'due', nil
        scope = scope.where(due_on: date_from..date_to)
      end
    end

    @agenda_items = scope.order(rank_score: :desc, due_on: :asc)
    @status_counts = AgendaItem.statuses.keys.index_with { |status| scope.where(status:).count }
    
    # Calculate min/max dates for date range picker (use created_at, due_on, and completed_at)
    all_items = policy_scope(AgendaItem)
    dates = []
    dates << all_items.minimum(:created_at)&.to_date
    dates << all_items.minimum(:due_on)
    dates << all_items.minimum(:completed_at)&.to_date
    dates << all_items.maximum(:created_at)&.to_date
    dates << all_items.maximum(:due_on)
    dates << all_items.maximum(:completed_at)&.to_date
    dates = dates.compact
    @min_date = dates.min || Date.current
    @max_date = dates.max || Date.current
  end

  def show
    authorize @agenda_item
    @message = @agenda_item.agenda_messages.build(user: current_user)
    @messages = @agenda_item.agenda_messages.includes(:user).order(created_at: :asc)
    @activity_logs = @agenda_item.activity_logs.includes(:user).recent
    @active_timer = @agenda_item.active_timer_for(current_user) if current_user
  end

  def new
    defaults = { priority_level: :normal, work_stream: :sprint, status: :backlog, complexity: 3, due_on: Date.current }
    @agenda_item = AgendaItem.new(defaults)
    @agenda_item.assign_attributes(prefill_params)
    
    # Default assignee to current user if internal role
    if current_user&.internal_role? && @agenda_item.assignee_id.blank?
      @agenda_item.assignee_id = current_user.id
    end
    
    # For clients: auto-associate sprint if only one exists
    if current_user&.client? && @agenda_item.client_id.present? && @agenda_item.sprint_id.blank?
      client_sprints = Sprint.joins(:project)
                            .where(projects: { client_id: @agenda_item.client_id })
      if client_sprints.count == 1
        @agenda_item.sprint_id = client_sprints.first.id
      elsif client_sprints.count > 1
        # If multiple sprints, default to latest
        latest_sprint = @sprints.joins(:project)
                               .where(projects: { client_id: @agenda_item.client_id })
                               .order(start_date: :desc, created_at: :desc)
                               .first
        @agenda_item.sprint_id = latest_sprint&.id
      end
    elsif @agenda_item.client_id.present? && @agenda_item.sprint_id.blank?
      # Default sprint to latest sprint for the client (non-client users)
      latest_sprint = @sprints.joins(:project)
                               .where(projects: { client_id: @agenda_item.client_id })
                               .order(start_date: :desc, created_at: :desc)
                               .first
      @agenda_item.sprint_id = latest_sprint&.id
    end
    
    apply_client_defaults(@agenda_item)
    authorize @agenda_item
  end

  def create
    @agenda_item = AgendaItem.new(agenda_item_params)
    apply_client_defaults(@agenda_item)
    authorize @agenda_item

    if @agenda_item.save
      ActivityLogger.log_creation(@agenda_item, current_user)
      redirect_to @agenda_item, success: 'Agenda item created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @agenda_item
  end

  def update
    authorize @agenda_item
    apply_client_defaults(@agenda_item)

    if @agenda_item.update(agenda_item_params)
      ActivityLogger.log_changes(@agenda_item, current_user)
      redirect_to @agenda_item, success: 'Agenda item updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @agenda_item
    @agenda_item.destroy
    redirect_to agenda_items_path, notice: 'Agenda item deleted.'
  end

  def complete
    authorize @agenda_item, :complete?

    if @agenda_item.update(status: :completed, completed_at: Time.current)
      ActivityLogger.log_changes(@agenda_item, current_user)
      redirect_to @agenda_item, success: 'Agenda item marked as completed.'
    else
      redirect_to @agenda_item, alert: 'Unable to complete agenda item.'
    end
  end

  def reopen
    authorize @agenda_item, :reopen?

    if @agenda_item.update(status: :in_progress, completed_at: nil)
      ActivityLogger.log_changes(@agenda_item, current_user)
      redirect_to @agenda_item, success: 'Agenda item reopened.'
    else
      redirect_to @agenda_item, alert: 'Unable to reopen agenda item.'
    end
  end

  def rank
    authorize @agenda_item, :rank?
    @agenda_item.refresh_rank!
    redirect_to @agenda_item, notice: 'Ranking recalculated.'
  end

  def approve
    authorize @agenda_item, :approve?
    approved = params[:approved] == 'true' || params[:approved] == true
    if @agenda_item.update(approved: approved)
      ActivityLogger.log_changes(@agenda_item, current_user)
      redirect_to @agenda_item, success: "Agenda item #{approved ? 'approved' : 'disapproved'}."
    else
      redirect_to @agenda_item, alert: 'Unable to update approval status.'
    end
  end

  def new_bulk
    authorize AgendaItem, :new?
    @default_assignee_id = current_user&.internal_role? ? current_user.id : nil
  end

  def create_bulk
    authorize AgendaItem, :create?
    
    @created_items = []
    @errors = []
    
    items = bulk_params[:items] || []
    items.each_with_index do |item_params, index|
      next if item_params.blank? || item_params[:title].blank? # Skip empty rows
      
      agenda_item = AgendaItem.new(bulk_item_params(item_params))
      agenda_item.client_id = bulk_params[:client_id] if bulk_params[:client_id].present?
      agenda_item.assignee_id = bulk_params[:assignee_id] if bulk_params[:assignee_id].present?
      agenda_item.sprint_id = bulk_params[:sprint_id] if bulk_params[:sprint_id].present?
      
      # Apply defaults
      agenda_item.priority_level ||= :normal
      agenda_item.work_stream ||= :sprint
      agenda_item.status ||= :backlog
      agenda_item.complexity ||= 3
      agenda_item.due_on ||= Date.current
      
      apply_client_defaults(agenda_item)
      authorize agenda_item, :create?
      
      if agenda_item.save
        ActivityLogger.log_creation(agenda_item, current_user)
        @created_items << agenda_item
      else
        @errors << { index: index + 1, errors: agenda_item.errors.full_messages }
      end
    end
    
    if @errors.empty? && @created_items.any?
      redirect_to agenda_items_path, success: "Successfully created #{@created_items.count} agenda item(s)."
    elsif @errors.any?
      @default_assignee_id = bulk_params[:assignee_id]
      flash.now[:alert] = "Some items could not be created. Please review the errors below."
      render :new_bulk, status: :unprocessable_entity
    else
      redirect_to new_bulk_agenda_items_path, alert: 'No agenda items were created. Please add at least one item with a title.'
    end
  end

  private

  def set_clients
    @sprint_client_id = determine_form_client_id
    @sprints = load_sprints
    
    if current_user&.client? && current_user.client.present?
      @clients = [current_user.client]
      @assignees = []
      # Count sprints for this client to determine if dropdown is needed
      @client_sprints_count = @sprints.joins(:project)
                                      .where(projects: { client_id: current_user.client_id })
                                      .count
    else
      @clients = policy_scope(Client).ordered
      @assignees = User.active.order(:first_name, :last_name)
      @client_sprints_count = nil
    end
  end

  def set_agenda_item
    @agenda_item = policy_scope(AgendaItem).find_by(id: params[:id])
    return redirect_to agenda_items_path, alert: 'Agenda item is not accessible.' unless @agenda_item
  end

  def agenda_item_params
    if current_user&.client?
      params.require(:agenda_item).permit(:title, :description, :work_stream, :priority_level, :due_on, :notes,
                                          :sprint_id)
    else
      params.require(:agenda_item).permit(:client_id, :assignee_id, :title, :description, :work_stream, :status,
                                          :priority_level, :complexity, :due_on, :started_on, :completed_at,
                                          :estimated_cost, :paid, :requested_by, :requested_by_email, :notes,
                                          :sprint_id)
    end
  end

  def filter_params
    permitted = params.fetch(:filters, {}).permit(:client_id, :status, :work_stream, :search, :date_from, :date_to, :date_type).to_h

    filters = {
      client_id: permitted['client_id'].presence&.to_i,
      status: permitted['status'].presence,
      work_stream: permitted['work_stream'].presence,
      search: permitted['search'].presence,
      date_from: permitted['date_from'].presence,
      date_to: permitted['date_to'].presence,
      date_type: permitted['date_type'].presence || 'due'
    }

    if current_user&.client? && current_user.client_id.present?
      filters[:client_id] = current_user.client_id
    end

    filters
  end

  def prefill_params
    return {} unless params[:agenda_item].present?
    return {} if current_user&.client?

    params.require(:agenda_item).permit(:client_id)
  end

  def apply_client_defaults(item)
    return unless current_user&.client?

    item.client_id = current_user.client_id if current_user.client_id.present?
    
    # Auto-assign to most frequent assignee for this client's agenda items
    if item.assignee_id.blank? && item.client_id.present?
      most_frequent_assignee = AgendaItem.where(client_id: item.client_id)
                                         .where.not(assignee_id: nil)
                                         .group(:assignee_id)
                                         .count
                                         .max_by { |_, count| count }
      item.assignee_id = most_frequent_assignee&.first if most_frequent_assignee
    end
    
    item.status ||= :backlog
    item.complexity ||= 3 # Medium complexity
    item.due_on ||= 12.hours.from_now.to_date # 12 hours from now
    item.requested_by = current_user.full_name
    item.requested_by_email = current_user.email

    # Auto-associate sprint if only one exists for this client
    if item.sprint_id.blank? && item.client_id.present?
      client_sprints = Sprint.joins(:project)
                            .where(projects: { client_id: item.client_id })
      if client_sprints.count == 1
        item.sprint_id = client_sprints.first.id
      end
    end

    if item.sprint.present? && item.sprint.project.client_id != current_user.client_id
      item.sprint = nil
      item.project = nil
    end
  end

  def determine_form_client_id
    return current_user.client_id.to_s if current_user&.client? && current_user.client_id.present?

    params.dig(:agenda_item, :client_id).presence ||
      @agenda_item&.client_id&.to_s ||
      @filters&.dig(:client_id)&.to_s
  end

  def load_sprints
    scope = Sprint.includes(project: :client).order(start_date: :desc, created_at: :desc)

    if current_user&.client? && current_user.client_id.present?
      scope = scope.joins(:project).where(projects: { client_id: current_user.client_id })
    end

    scope
  end

  def bulk_params
    params.permit(:client_id, :assignee_id, :sprint_id, items: [:title, :description, :work_stream, :status, :priority_level, :complexity, :due_on])
  end

  def bulk_item_params(item_params)
    return {} unless item_params.is_a?(ActionController::Parameters) || item_params.is_a?(Hash)
    item_params.permit(:title, :description, :work_stream, :status, :priority_level, :complexity, :due_on)
  end
end
