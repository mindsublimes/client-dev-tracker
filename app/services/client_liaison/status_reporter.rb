# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module ClientLiaison
  class StatusReporter
    class Error < StandardError; end
    class ConfigError < Error; end
    class DeliveryError < Error; end

    NOISE_PATTERNS = [
      /helper/i,
      /refactor/i,
      /lint/i,
      /rubocop/i,
      /chore/i,
      /rename/i,
      /cleanup/i
    ].freeze

    class << self
      def deliver_all_pending!(since: 1.day.ago)
        client_ids = AgendaItem.completed_unreported.where("completed_at >= ?", since).distinct.pluck(:client_id)
        client_ids.sum { |client_id| deliver_for_client!(client_id, since: since) }
      end

      def deliver_for_client!(client_or_id, since: 1.day.ago)
        client = client_or_id.is_a?(Client) ? client_or_id : Client.find(client_or_id)
        items = pending_items_for(client, since:)
        return 0 if items.empty?

        payload = build_payload(client:, items:, since:)
        response_code = post_webhook!(payload)
        mark_reported!(items)
        log_delivery!(
          client: client,
          status: "sent",
          sent_at: Time.current,
          completed_items_count: items.size,
          summary: payload[:summary],
          webhook_response_code: response_code,
          payload_json: JSON.generate(payload)
        )
        items.size
      rescue DeliveryError => e
        log_delivery!(
          client: client,
          status: "failed",
          sent_at: Time.current,
          completed_items_count: items&.size.to_i,
          summary: payload&.dig(:summary),
          error_message: e.message.to_s.truncate(800),
          payload_json: payload.present? ? JSON.generate(payload) : nil
        )
        raise
      end

      private

      def pending_items_for(client, since:)
        AgendaItem.includes(:project, :assignee)
                  .where(client_id: client.id, status: :completed, client_liaison_reported_at: nil)
                  .where("completed_at >= ?", since)
                  .order(completed_at: :asc)
      end

      def build_payload(client:, items:, since:)
        summary = summarize(client:, items:, since:)
        {
          event: "client_status_update",
          generated_at: Time.current.iso8601,
          date_range: {
            from: since.to_date.iso8601,
            to: Date.current.iso8601
          },
          client: {
            id: client.id,
            name: client.name,
            code: client.code
          },
          summary: summary,
          completed_count: items.size,
          completed_items: items.map { |item| item_payload(item) }
        }
      end

      def summarize(client:, items:, since:)
        value_items = items.reject { |item| noise_item?(item) }
        return fallback_summary(client:, items: value_items.presence || items, since:) unless llm_enabled?

        llm_summary = llm_summary(client:, items: value_items.presence || items, since:)
        llm_summary.presence || fallback_summary(client:, items: value_items.presence || items, since:)
      rescue StandardError
        fallback_summary(client:, items: value_items.presence || items, since:)
      end

      def noise_item?(item)
        text = [item.title, item.description].join(" ")
        NOISE_PATTERNS.any? { |pat| text.match?(pat) }
      end

      def llm_enabled?
        (ENV["OPENAI_API_KEY"].presence || ENV["OPENAI_ACCESS_TOKEN"].presence).present?
      end

      def llm_summary(client:, items:, since:)
        require "openai" unless defined?(OpenAI)

        token = ENV["OPENAI_API_KEY"].presence || ENV["OPENAI_ACCESS_TOKEN"].presence
        client_api = OpenAI::Client.new(access_token: token)

        prompt_lines = items.first(25).map do |item|
          "- #{item.title} | project=#{item.project&.name || "N/A"} | completed=#{item.completed_at&.to_date} | details=#{item.description.to_s.tr("\n", " ").truncate(280)}"
        end.join("\n")

        system = <<~TEXT.strip
          You are a client liaison. Rewrite technical delivery notes into concise business-value updates.
          Return JSON only: {"summary":"...","highlights":["...","..."]}.
          Avoid code-level jargon, filenames, and internal implementation details.
          Emphasize user impact, reliability, performance, UX, and delivery progress.
          Keep summary under 120 words and each highlight under 22 words.
        TEXT

        user = <<~TEXT
          Client: #{client.name}
          Date range: #{since.to_date} to #{Date.current}
          Completed work:
          #{prompt_lines}
        TEXT

        response = client_api.chat(
          parameters: {
            model: ENV.fetch("OPENAI_CLIENT_STATUS_MODEL", "gpt-4o-mini"),
            response_format: { type: "json_object" },
            messages: [{ role: "system", content: system }, { role: "user", content: user }],
            max_tokens: 500
          }
        )

        raw = response.dig("choices", 0, "message", "content")
        data = JSON.parse(raw)
        summary = data["summary"].to_s.strip
        highlights = Array(data["highlights"]).map { |h| h.to_s.strip }.reject(&:blank?).first(5)

        [summary, *highlights].reject(&:blank?).join("\n")
      end

      def fallback_summary(client:, items:, since:)
        project_names = items.map { |i| i.project&.name }.compact.uniq.first(4)
        summary = "Between #{since.to_date} and #{Date.current}, the team completed #{items.size} delivery item"
        summary += "s" unless items.size == 1
        summary += " for #{client.name}"
        summary += " across #{project_names.join(', ')}" if project_names.any?
        summary + "."
      end

      def item_payload(item)
        {
          id: item.id,
          title: item.title,
          project: item.project&.name,
          assignee: item.assignee&.full_name,
          completed_at: item.completed_at&.iso8601
        }
      end

      def post_webhook!(payload)
        hook = ENV["CLIENT_LIAISON_WEBHOOK_URL"].to_s.strip
        raise ConfigError, "CLIENT_LIAISON_WEBHOOK_URL is not set." if hook.blank?

        uri = URI.parse(hook)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        secret = ENV["CLIENT_LIAISON_WEBHOOK_SECRET"].to_s.strip
        req["X-Webhook-Secret"] = secret if secret.present?
        req.body = JSON.generate(payload)

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 60, open_timeout: 15) do |http|
          http.request(req)
        end

        return res.code.to_i if (200..299).cover?(res.code.to_i)

        raise DeliveryError, "Webhook failed HTTP #{res.code}: #{res.body.to_s.truncate(300)}"
      end

      def mark_reported!(items)
        AgendaItem.where(id: items.map(&:id)).update_all(client_liaison_reported_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      end

      def log_delivery!(attributes)
        ClientStatusDelivery.create!(attributes)
      rescue StandardError => e
        Rails.logger.error("[ClientLiaison::StatusReporter] Failed to log delivery: #{e.class}: #{e.message}")
      end
    end
  end
end
