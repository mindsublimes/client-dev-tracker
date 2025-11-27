class AgendaItemPolicy < ApplicationPolicy
  def dashboard?
    user.present?
  end

  def index?
    user.present?
  end

  def show?
    accessible_record?
  end

  def create?
    return client_access? && user.client_id.present? if client_access?

    elevated_access?
  end

  def update?
    return false if client_access?
    return record.assignee_id == user.id if user&.developer?

    elevated_access?
  end

  alias edit? update?

  def destroy?
    admin_access?
  end

  def complete?
    update?
  end

  def reopen?
    update?
  end

  def rank?
    elevated_access?
  end

  def approve?
    return false unless user
    # Client admins can approve items for their client
    return true if user.client? && user.client_admin? && record.client_id == user.client_id
    # Internal roles (admin, lead, analyst) can approve any item
    return true if user.internal_role?
    false
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.client? && user.client_id.present?
        scope.where(client_id: user.client_id)
      elsif user.developer?
        scope.where(assignee_id: user.id)
      else
        scope.all
      end
    end
  end

  private

  def accessible_record?
    return false unless user

    if user.client?
      record.client_id == user.client_id
    elsif user.developer?
      record.assignee_id == user.id
    else
      true
    end
  end
end
