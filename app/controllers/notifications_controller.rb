class NotificationsController < ApplicationController
  before_action :set_notification, only: [:update]

  def index
    authorize Notification
    @notifications = current_user.notifications.includes(:agenda_item).recent.limit(20)
    @unread_count = current_user.notifications.unread.count
  end

  def update
    authorize @notification
    @notification.mark_as_read!
    
    redirect_to = params[:redirect_to] || @notification.agenda_item
    
    respond_to do |format|
      format.html { redirect_to redirect_to }
      format.json { render json: { success: true } }
    end
  end

  def mark_all_read
    authorize Notification, :mark_all_read?
    current_user.notifications.unread.update_all(read: true)
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: dashboard_path) }
      format.json { render json: { success: true } }
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end

