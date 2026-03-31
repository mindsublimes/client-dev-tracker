# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Financial
  # Optional direct QuickBooks Online invoice create (OAuth access token must be kept fresh externally).
  # Configure: QUICKBOOKS_ACCESS_TOKEN, QUICKBOOKS_REALM_ID, QUICKBOOKS_CUSTOMER_ID, QUICKBOOKS_LINE_ITEM_ID
  # (line item = a Service or Product already in the QBO company).
  class QuickbooksInvoicePublisher
    API_BASE = "https://quickbooks.api.intuit.com/v3/company"

    class << self
      def configured?
        %w[QUICKBOOKS_ACCESS_TOKEN QUICKBOOKS_REALM_ID QUICKBOOKS_CUSTOMER_ID QUICKBOOKS_LINE_ITEM_ID].all? do |key|
          ENV[key].to_s.strip.present?
        end
      end

      def publish!(invoice)
        return false unless configured?

        realm = ENV["QUICKBOOKS_REALM_ID"].to_s.strip
        uri = URI("#{API_BASE}/#{realm}/invoice?minorversion=65")
        item = invoice.agenda_item

        body = {
          CustomerRef: { value: ENV["QUICKBOOKS_CUSTOMER_ID"].to_s.strip },
          Line: [
            {
              Amount: invoice.amount.to_f,
              DetailType: "SalesItemLineDetail",
              SalesItemLineDetail: {
                ItemRef: { value: ENV["QUICKBOOKS_LINE_ITEM_ID"].to_s.strip },
                Qty: 1,
                UnitPrice: invoice.amount.to_f
              }
            }
          ],
          PrivateNote: "DevTracker milestone ##{item&.id}: #{item&.title}".truncate(4000)
        }

        req = Net::HTTP::Post.new(uri)
        req["Authorization"] = "Bearer #{ENV['QUICKBOOKS_ACCESS_TOKEN'].to_s.strip}"
        req["Content-Type"] = "application/json"
        req["Accept"] = "application/json"
        req.body = JSON.generate(body)

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60, open_timeout: 15) do |http|
          http.request(req)
        end

        unless (200..299).cover?(res.code.to_i)
          invoice.update_columns(sync_error: "QuickBooks HTTP #{res.code}: #{res.body.to_s.truncate(400)}") # rubocop:disable Rails/SkipsModelValidations
          return false
        end

        parsed = JSON.parse(res.body)
        qbo = parsed["Invoice"] || parsed["invoice"] || {}
        doc_id = qbo["Id"]
        doc_number = qbo["DocNumber"]
        sync_token = qbo["SyncToken"]

        invoice.update!(
          external_provider: :quickbooks,
          external_id: doc_id&.to_s,
          external_url: nil,
          sync_error: nil
        )
        Rails.logger.info("[QuickbooksInvoicePublisher] QBO Invoice Id=#{doc_id} DocNumber=#{doc_number}") if doc_id
        true
      rescue StandardError => e
        invoice.update_columns(sync_error: e.message.to_s.truncate(500)) # rubocop:disable Rails/SkipsModelValidations
        false
      end
    end
  end
end
