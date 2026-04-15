# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :client
  belongs_to :agenda_item

  enum :status, { open: "open", paid: "paid", void: "void" }, prefix: :invoice
  enum :external_provider, {
    none: "none",
    webhook: "webhook",
    quickbooks: "quickbooks",
    xero: "xero"
  }, prefix: :provider

  validates :amount, numericality: { greater_than: 0 }
  validates :agenda_item_id, uniqueness: true
  validates :issued_at, presence: true

  scope :due_for_reminders, -> { invoice_open.joins(:agenda_item).where(agenda_items: { paid: false }) }

  def days_outstanding
    return 0 if issued_at.blank?

    (Date.current - issued_at.to_date).to_i
  end
end
