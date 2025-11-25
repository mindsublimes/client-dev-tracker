class TimeEntryPolicy < ApplicationPolicy
  def create?
    return false unless user
    return true if user.internal_role?
    return true if user.client? && record.agenda_item.client_id == user.client_id

    false
  end

  def start?
    return false unless user
    return true if user.internal_role?
    return true if user.client? && record.agenda_item.client_id == user.client_id

    false
  end

  def stop?
    return false unless user
    return true if record.user_id == user.id

    false
  end

  def destroy?
    return false unless user
    return true if user.admin? || user.lead? || user.analyst?
    return true if record.user_id == user.id

    false
  end
end

