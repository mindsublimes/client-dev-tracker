class SprintPolicy < ApplicationPolicy
  def index?
    user&.internal_role?
  end

  def show?
    return false unless user
    return true if user.internal_role?
    user.client? && record.project.client_id == user.client_id
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
        scope.joins(:project).where(projects: { client_id: user.client_id })
      else
        scope.all
      end
    end
  end
end
