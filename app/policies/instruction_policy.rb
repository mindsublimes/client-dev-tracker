class InstructionPolicy < ApplicationPolicy
  def show?
    return false unless user
    return true if user.internal_role?
    user.client? && record.page.project.client_id == user.client_id
  end

  def create?
    user&.internal_role?
  end

  def new?
    create?
  end

  def update?
    user&.internal_role?
  end

  def edit?
    update?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.client?
        scope.joins(page: :project).where(projects: { client_id: user.client_id })
      elsif user.developer?
        # Developers see instructions for pages in projects they're assigned to
        assigned_project_ids = AgendaItem.where(assignee_id: user.id)
                                         .where.not(project_id: nil)
                                         .distinct
                                         .pluck(:project_id)
        scope.joins(page: :project).where(projects: { id: assigned_project_ids })
      else
        scope.all
      end
    end
  end
end

