# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Financial
  # POST invoice JSON to Zapier/n8n; your flow creates the invoice in QuickBooks or Xero.
  class WebhookInvoicePublisher
    class << self
      def configured?
        ENV["FINANCIAL_INVOICE_WEBHOOK_URL"].to_s.strip.present?
      end

      def publish!(invoice)
        return false unless configured?

        hook = ENV["FINANCIAL_INVOICE_WEBHOOK_URL"].to_s.strip
        uri = URI.parse(hook)
        payload = build_payload(invoice)

        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        secret = ENV["FINANCIAL_INVOICE_WEBHOOK_SECRET"].to_s.strip
        req["X-Webhook-Secret"] = secret if secret.present?
        req.body = JSON.generate(payload)

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 60, open_timeout: 15) do |http|
          http.request(req)
        end

        unless (200..299).cover?(res.code.to_i)
          invoice.update_columns(sync_error: "Webhook HTTP #{res.code}: #{res.body.to_s.truncate(400)}") # rubocop:disable Rails/SkipsModelValidations
          return false
        end

        external = parse_external(res.body)
        invoice.update!(
          external_provider: :webhook,
          external_id: external[:id],
          external_url: external[:url],
          sync_error: nil
        )
        true
      rescue StandardError => e
        invoice.update_columns(sync_error: e.message.to_s.truncate(500)) # rubocop:disable Rails/SkipsModelValidations
        false
      end

      private

      def build_payload(invoice)
        item = invoice.agenda_item
        {
          event: "invoice_requested",
          provider_hint: ENV["FINANCIAL_WEBHOOK_ACCOUNTING_TARGET"].to_s.presence, # e.g. "quickbooks" | "xero"
          invoice: {
            id: invoice.id,
            amount: invoice.amount.to_f,
            currency: invoice.currency,
            issued_at: invoice.issued_at.iso8601,
            line_description: item&.title,
            internal_reference: "agenda_item:#{item&.id}"
          },
          client: {
            id: invoice.client_id,
            name: invoice.client&.name,
            code: invoice.client&.code,
            contact_email: invoice.client&.contact_email,
            billing_email: invoice.client&.contact_email.presence || item&.requested_by_email
          },
          agenda_item: {
            id: item&.id,
            title: item&.title,
            completed_at: item&.completed_at&.iso8601
          }
        }
      end

      def parse_external(body)
        data = JSON.parse(body)
        data = data["data"] if data.is_a?(Hash) && data["data"].is_a?(Hash)
        return {} unless data.is_a?(Hash)

        id = data["external_id"] || data["invoice_id"] || data["Id"]
        url = data["external_url"] || data["invoice_url"] || data["InvoiceLink"]
        { id: id&.to_s, url: url&.to_s }
      rescue JSON::ParserError
        {}
      end
    end
  end
end
