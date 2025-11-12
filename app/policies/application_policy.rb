class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    elevated_access?
  end

  def new?
    create?
  end

  def update?
    elevated_access?
  end

  def edit?
    update?
  end

  def destroy?
    admin_access?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end

  private

  def elevated_access?
    user.present? && !user.viewer?
  end

  def admin_access?
    user.present? && user.admin?
  end
end
