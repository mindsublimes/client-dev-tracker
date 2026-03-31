# frozen_string_literal: true

class ProcessPaymentReminderJob < ApplicationJob
  queue_as :default

  REMINDER_DAYS = [7, 14, 30].freeze

  def perform
    Invoice.due_for_reminders.find_each do |invoice|
      to = billing_recipient_email(invoice)
      next if to.blank?

      days = invoice.days_outstanding
      stage = invoice.reminder_stage
      next if stage >= REMINDER_DAYS.size

      target_day = REMINDER_DAYS[stage]
      next if days < target_day

      BillingMailer.with(invoice: invoice, reminder_day: target_day).payment_reminder.deliver_later
      invoice.update!(reminder_stage: stage + 1, last_reminder_sent_at: Time.current)
    end
  end

  private

  def billing_recipient_email(invoice)
    item = invoice.agenda_item
    invoice.client&.contact_email.presence || item&.requested_by_email.presence
  end
end
