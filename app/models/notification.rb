class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :agenda_item

  enum notification_type: {
    assigned: 'assigned',
    message: 'message',
    status_changed: 'status_changed'
  }

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_read!
    update(read: true)
  end
end


