class AgendaItemsController < ApplicationController
  before_action :set_clients, only: %i[index new create edit update]
  before_action :set_agenda_item, only: %i[show edit update destroy complete reopen rank]

  def index
    authorize AgendaItem

    scope = policy_scope(AgendaItem.includes(:client, :assignee))
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
  end

  def new
    defaults = { priority_level: :normal, work_stream: :sprint, status: :backlog, complexity: 3, due_on: Date.current + 7.days }
    @agenda_item = AgendaItem.new(defaults)
    @agenda_item.assign_attributes(prefill_params)
    authorize @agenda_item
  end

  def create
    @agenda_item = AgendaItem.new(agenda_item_params)
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
    @clients = policy_scope(Client).ordered
    @assignees = User.active.order(:first_name, :last_name)
  end

  def set_agenda_item
    @agenda_item = policy_scope(AgendaItem).find(params[:id])
  end

  def agenda_item_params
    params.require(:agenda_item).permit(:client_id, :assignee_id, :title, :description, :work_stream, :status,
                                        :priority_level, :complexity, :due_on, :started_on, :completed_at,
                                        :estimated_cost, :paid, :requested_by, :requested_by_email, :notes)
  end

  def filter_params
    permitted = params.fetch(:filters, {}).permit(:client_id, :status, :work_stream, :search).to_h

    {
      client_id: permitted['client_id'].presence&.to_i,
      status: permitted['status'].presence,
      work_stream: permitted['work_stream'].presence,
      search: permitted['search'].presence
    }
  end

  def prefill_params
    return {} unless params[:agenda_item].present?

    params.require(:agenda_item).permit(:client_id)
  end
end
