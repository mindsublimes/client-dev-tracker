class SprintPolicy < ApplicationPolicy
  def show?
    return false unless user
    return true if user.internal_role?
    user.client? && record.project.client_id == user.client_id
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
