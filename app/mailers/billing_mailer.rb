# frozen_string_literal: true

class BillingMailer < ApplicationMailer
  default from: -> { ENV.fetch("AGENCY_BILLING_FROM_EMAIL", "from@example.com") }

  def invoice_issued
    @invoice = params[:invoice]
    @agenda_item = @invoice.agenda_item
    @client = @invoice.client
    to = recipient_email(@invoice)
    mail(to:, subject: "Invoice for completed milestone: #{@agenda_item.title}") if to.present?
  end

  def payment_reminder
    @invoice = params[:invoice]
    @reminder_day = params[:reminder_day]
    @agenda_item = @invoice.agenda_item
    @client = @invoice.client
    to = recipient_email(@invoice)
    mail(to:, subject: friendly_reminder_subject) if to.present?
  end

  private

  def recipient_email(invoice)
    invoice.client&.contact_email.presence || invoice.agenda_item&.requested_by_email.presence
  end

  def friendly_reminder_subject
    case @reminder_day
    when 7
      "Friendly reminder: invoice outstanding (#{@client&.name})"
    when 14
      "Second reminder: invoice still open (#{@client&.name})"
    when 30
      "Please arrange payment: invoice past due (#{@client&.name})"
    else
      "Payment reminder (#{@client&.name})"
    end
  end
end
