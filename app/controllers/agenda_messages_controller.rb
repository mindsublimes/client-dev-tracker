class AgendaMessagesController < ApplicationController
  before_action :set_agenda_item

  def create
    @agenda_message = @agenda_item.agenda_messages.build(agenda_message_params.merge(user: current_user))
    authorize @agenda_message

    if @agenda_message.save
      ActivityLogger.log_message(@agenda_message)
      redirect_to @agenda_item, success: 'Update posted.'
    else
      @message = @agenda_message
      @messages = @agenda_item.agenda_messages.includes(:user).order(created_at: :asc)
      @activity_logs = @agenda_item.activity_logs.includes(:user).recent
      @active_timer = @agenda_item.active_timer_for(current_user) if current_user
      render 'agenda_items/show', status: :unprocessable_entity
    end
  end

  private

  def set_agenda_item
    @agenda_item = policy_scope(AgendaItem).find(params[:agenda_item_id])
    authorize @agenda_item, :show?
  end

  def agenda_message_params
    params.require(:agenda_message).permit(:body, :kind, files: [])
  end
end
