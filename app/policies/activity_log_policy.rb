class ActivityLogPolicy < ApplicationPolicy
  def index?
    user.present?
  end
end
