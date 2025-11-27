class NotificationsController < ApplicationController
  before_action :set_notification, only: [:update]

  def index
    authorize Notification
    @notifications = current_user.notifications.includes(:agenda_item).recent.limit(20)
    @unread_count = current_user.notifications.unread.count
    
    respond_to do |format|
      format.html
      format.json do
        last_id = params[:last_id].to_i
        unread_only = params[:unread_only] == 'true'
        scope = current_user.notifications.includes(:agenda_item).recent
        scope = scope.unread if unread_only
        scope = scope.where('notifications.id > ?', last_id) if last_id > 0
        notifications = scope.limit(10)
        
        render json: {
          notifications: notifications.map do |n|
            {
              id: n.id,
              type: n.notification_type,
              message: n.message,
              agenda_item_id: n.agenda_item_id,
              read: n.read,
              created_at: n.created_at.iso8601
            }
          end
        }
      end
    end
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

