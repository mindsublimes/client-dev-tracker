class TimeEntriesController < ApplicationController
  before_action :set_agenda_item
  before_action :set_time_entry, only: [:destroy]

  def create
    @time_entry = @agenda_item.time_entries.build(time_entry_params.merge(user: current_user))
    authorize @time_entry

    # Calculate hours from timer if start_time and end_time are provided but hours is not
    if @time_entry.start_time.present? && @time_entry.end_time.present? && @time_entry.hours.blank?
      @time_entry.hours = @time_entry.calculate_hours
    end

    # Set date if not provided
    @time_entry.date ||= Date.current

    if @time_entry.save
      redirect_to @agenda_item, success: 'Time logged successfully.'
    else
      @message = @agenda_item.agenda_messages.build(user: current_user)
      @messages = @agenda_item.agenda_messages.includes(:user).order(created_at: :asc)
      @activity_logs = @agenda_item.activity_logs.includes(:user).recent
      @active_timer = @agenda_item.active_timer_for(current_user) if current_user
      flash.now[:alert] = 'Unable to log time.'
      render 'agenda_items/show', status: :unprocessable_entity
    end
  end

  def start
    # Check if there's already an active timer
    if @agenda_item.has_active_timer_for?(current_user)
      redirect_to @agenda_item, alert: 'You already have an active timer for this item.'
      return
    end

    @time_entry = @agenda_item.time_entries.build(
      user: current_user,
      start_time: Time.current,
      date: Date.current
    )
    authorize @time_entry

    if @time_entry.save
      redirect_to @agenda_item, success: 'Timer started.'
    else
      redirect_to @agenda_item, alert: 'Unable to start timer.'
    end
  end

  def stop
    @time_entry = @agenda_item.active_timer_for(current_user)
    return redirect_to @agenda_item, alert: 'No active timer found.' unless @time_entry

    authorize @time_entry, :stop?
    @time_entry.stop_timer!
    redirect_to @agenda_item, success: 'Timer stopped. Time logged successfully.'
  end

  def destroy
    authorize @time_entry
    @time_entry.destroy
    redirect_to @agenda_item, success: 'Time entry deleted.'
  end

  private

  def set_agenda_item
    @agenda_item = policy_scope(AgendaItem).find(params[:agenda_item_id])
    authorize @agenda_item, :show?
  end

  def set_time_entry
    @time_entry = @agenda_item.time_entries.find(params[:id])
  end

  def time_entry_params
    params.require(:time_entry).permit(:hours, :date, :notes, :start_time, :end_time)
  end
end

