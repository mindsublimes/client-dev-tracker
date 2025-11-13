class ClientPolicy < ApplicationPolicy
  def index?
    return false unless user
    !client_access?
  end

  def show?
    return false unless user
    return false if client_access?

    if user.developer?
      record.agenda_items.where(assignee_id: user.id).exists?
    else
      elevated_access?
    end
  end

  def create?
    manager_access?
  end

  def new?
    create?
  end

  def update?
    manager_access?
  end

  def edit?
    update?
  end

  def destroy?
    admin_access?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.client? && user.client_id.present?
        scope.where(id: user.client_id)
      elsif user.developer?
        scope.joins(:agenda_items).where(agenda_items: { assignee_id: user.id }).distinct
      else
        scope.all
      end
    end
  end
end
