class ProjectPolicy < ApplicationPolicy
  def index?
    user&.internal_role?
  end

  def show?
    return false unless user
    return true if user.internal_role?
    user.client? && record.client_id == user.client_id
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

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.client?
        scope.where(client_id: user.client_id)
      else
        scope.all
      end
    end
  end
end
