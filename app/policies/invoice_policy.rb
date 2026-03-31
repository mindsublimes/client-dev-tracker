# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    user&.internal_role?
  end

  def show?
    user&.internal_role?
  end

  def mark_paid?
    user&.internal_role?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user&.internal_role?

      scope.all
    end
  end
end
