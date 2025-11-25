class AgendaItemsController < ApplicationController
  before_action :set_clients, only: %i[index new create edit update]
  before_action :set_agenda_item, only: %i[show edit update destroy complete reopen rank]

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

    @agenda_items = scope.order(rank_score: :desc, due_on: :asc)
    @status_counts = AgendaItem.statuses.keys.index_with { |status| scope.where(status:).count }
  end

  def show
    authorize @agenda_item
    @message = @agenda_item.agenda_messages.build(user: current_user)
    @messages = @agenda_item.agenda_messages.includes(:user).order(created_at: :asc)
    @activity_logs = @agenda_item.activity_logs.includes(:user).recent
    @active_timer = @agenda_item.active_timer_for(current_user) if current_user
  end

  def new
    defaults = { priority_level: :normal, work_stream: :sprint, status: :backlog, complexity: 3, due_on: Date.current + 7.days }
    @agenda_item = AgendaItem.new(defaults)
    @agenda_item.assign_attributes(prefill_params)
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

  private

  def set_clients
    if current_user&.client? && current_user.client.present?
      @clients = [current_user.client]
      @assignees = []
    else
      @clients = policy_scope(Client).ordered
      @assignees = User.active.order(:first_name, :last_name)
    end

    @sprint_client_id = determine_form_client_id
    @sprints = load_sprints
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
    permitted = params.fetch(:filters, {}).permit(:client_id, :status, :work_stream, :search).to_h

    filters = {
      client_id: permitted['client_id'].presence&.to_i,
      status: permitted['status'].presence,
      work_stream: permitted['work_stream'].presence,
      search: permitted['search'].presence
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
    item.assignee_id = nil
    item.status ||= :backlog
    item.complexity ||= 3
    item.requested_by = current_user.full_name
    item.requested_by_email = current_user.email

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
    scope = Sprint.includes(project: :client).order(:name)

    if current_user&.client? && current_user.client_id.present?
      scope = scope.joins(:project).where(projects: { client_id: current_user.client_id })
    end

    scope
  end
end
