class UserPolicy < ApplicationPolicy
  def index?
    manager_access?
  end

  def show?
    manager_access?
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
      return scope.none unless manager_access?

      scope.all
    end

    private

    def manager_access?
      user.present? && (user.admin? || user.lead? || user.analyst?)
    end
  end
end
