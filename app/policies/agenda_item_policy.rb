class AgendaItemPolicy < ApplicationPolicy
  def dashboard?
    user.present?
  end

  def complete?
    elevated_access?
  end

  def reopen?
    elevated_access?
  end

  def rank?
    elevated_access?
  end
end
