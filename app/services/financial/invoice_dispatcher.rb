# frozen_string_literal: true

module Financial
  # Tries QuickBooks REST first (optional env), then a generic webhook for Zapier/n8n → QuickBooks/Xero.
  class InvoiceDispatcher
    class << self
      def dispatch!(invoice)
        invoice.update_columns(sync_error: nil) # rubocop:disable Rails/SkipsModelValidations

        if QuickbooksInvoicePublisher.configured?
          return if QuickbooksInvoicePublisher.publish!(invoice)
        end

        WebhookInvoicePublisher.publish!(invoice) if WebhookInvoicePublisher.configured?
      end
    end
  end
end
