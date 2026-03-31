# frozen_string_literal: true

module Financial
  # Creates a local Invoice when a billing milestone agenda item is completed, syncs to
  # QuickBooks (if configured) or a Zapier/n8n webhook, then emails the client.
  class MilestoneInvoiceCreator
    class << self
      def call(agenda_item_id)
        item = AgendaItem.find_by(id: agenda_item_id)
        return unless milestone_ready?(item)
        return if item.invoice.present?

        inv = nil
        Invoice.transaction do
          inv = Invoice.create!(
            client_id: item.client_id,
            agenda_item_id: item.id,
            amount: item.estimated_cost,
            issued_at: Time.current,
            currency: ENV.fetch("FINANCIAL_DEFAULT_CURRENCY", "USD")
          )
          InvoiceDispatcher.dispatch!(inv)
          inv.reload
        end

        return unless inv

        to = billing_recipient_email(item)
        BillingMailer.with(invoice: inv).invoice_issued.deliver_later if to.present?
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        Rails.logger.error("[Financial::MilestoneInvoiceCreator] #{e.class}: #{e.message}")
      end

      private

      def milestone_ready?(item)
        item&.completed? && item.billing_milestone? && item.estimated_cost.present? && item.estimated_cost.to_f.positive?
      end

      def billing_recipient_email(item)
        item.client&.contact_email.presence || item.requested_by_email.presence
      end
    end
  end
end
