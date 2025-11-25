class NotificationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def update?
    record.user_id == user.id
  end

  def mark_all_read?
    user.present?
  end
end

