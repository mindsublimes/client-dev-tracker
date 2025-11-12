class AgendaMessagePolicy < ApplicationPolicy
  def create?
    elevated_access?
  end
end
