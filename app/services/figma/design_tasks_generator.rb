# frozen_string_literal: true

require "json"

module Figma
  # Turns a list of Figma frames/components into concrete implementation line items.
  # Uses Anthropic Claude when ANTHROPIC_API_KEY is set and FIGMA_TASKS_LLM=anthropic (default openai).
  # Uses OpenAI when OPENAI_API_KEY / OPENAI_ACCESS_TOKEN is set (ruby-openai gem).
  # Without any LLM, falls back to one task per frame with generic wording.
  class DesignTasksGenerator
    class << self
      def call(frames:, project_name:, project_description: nil)
        return [] if frames.blank?

        case llm_backend
        when :anthropic
          generate_with_anthropic(frames, project_name, project_description)
        when :openai
          generate_with_openai(frames, project_name, project_description)
        else
          fallback_tasks(frames)
        end
      end

      def llm_backend
        anthropic_key = ENV["ANTHROPIC_API_KEY"].present?
        prefer_anthropic = ENV["FIGMA_TASKS_LLM"].to_s.downcase == "anthropic"

        if anthropic_key && (prefer_anthropic || openai_token.blank?)
          return :anthropic
        end

        if openai_token.present?
          begin
            require "openai" unless defined?(OpenAI)
          rescue LoadError
            return :anthropic if anthropic_key
            return nil
          end
          return :openai if defined?(OpenAI)
        end

        return :anthropic if anthropic_key

        nil
      end

      private

      def openai_token
        ENV["OPENAI_API_KEY"].presence || ENV["OPENAI_ACCESS_TOKEN"].presence
      end

      def system_instructions
        <<~TEXT.strip
          You are a senior frontend engineer. You receive a list of Figma frames and components
          (name, type, hierarchy path). Produce a JSON object with a single key "tasks" whose value
          is an array of implementation tickets for developers.

          Rules:
          - Each task must have "title" (short, imperative, specific) and "description" (1–3 sentences:
            what to build, key UI behaviors, responsive/accessibility notes if obvious).
          - Prefer technically actionable wording (layout system, breakpoints, interaction states, keyboard/ARIA where relevant).
          - Merge overly granular frames into sensible tickets when it reduces noise (e.g. multiple
            icon wrappers → one task).
          - Aim for roughly 5–25 tasks unless the input is tiny; cap at 30 tasks.
          - Titles should sound like backlog items, e.g. "Build responsive 3-column grid for Services section".
          - Output ONLY valid JSON, no markdown fences.
        TEXT
      end

      def user_payload(frames, project_name, project_description)
        lines = frames.map do |f|
          bits = ["- [#{f[:type]}] #{f[:name]} — #{f[:path]}"]
          bits << "size=#{f[:size]}" if f[:size].present?
          bits << "layoutMode=#{f[:layout_mode]}" if f[:layout_mode].present?
          bits << "itemSpacing=#{f[:item_spacing]}" if f[:item_spacing].present?
          bits << "primaryAlign=#{f[:primary_axis_align]}" if f[:primary_axis_align].present?
          bits << "counterAlign=#{f[:counter_axis_align]}" if f[:counter_axis_align].present?
          bits << "padding=#{f[:padding].to_json}" if f[:padding].present?
          bits << "overflowDirection=#{f[:overflow_direction]}" if f[:overflow_direction].present?
          bits << "constraints=#{f[:constraints].to_json}" if f[:constraints].present?
          bits.join(" | ")
        end.join("\n")
        parts = ["Project: #{project_name}"]
        parts << "Context: #{project_description}" if project_description.present?
        parts << "Figma structure:\n#{lines}"
        parts.join("\n\n")
      end

      def generate_with_openai(frames, project_name, project_description)
        client = OpenAI::Client.new(access_token: openai_token)
        response = client.chat(
          parameters: {
            model: ENV.fetch("OPENAI_FIGMA_TASKS_MODEL", "gpt-4o-mini"),
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: system_instructions },
              { role: "user", content: user_payload(frames, project_name, project_description) }
            ],
            max_tokens: 4096
          }
        )
        raw = response.dig("choices", 0, "message", "content")
        parse_tasks_json(raw, frames)
      rescue StandardError
        fallback_tasks(frames)
      end

      def generate_with_anthropic(frames, project_name, project_description)
        require "net/http"
        require "uri"

        uri = URI("https://api.anthropic.com/v1/messages")
        body = {
          model: ENV.fetch("ANTHROPIC_FIGMA_TASKS_MODEL", "claude-3-5-sonnet-20241022"),
          max_tokens: 4096,
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: "#{system_instructions}\n\n#{user_payload(frames, project_name, project_description)}" }
              ]
            }
          ]
        }

        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
        req["anthropic-version"] = "2023-06-01"
        req.body = body.to_json

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120, open_timeout: 30) do |http|
          http.request(req)
        end

        unless res.code.to_i == 200
          return fallback_tasks(frames)
        end

        parsed = JSON.parse(res.body)
        text = parsed.dig("content", 0, "text")
        parse_tasks_json(text, frames)
      rescue StandardError
        fallback_tasks(frames)
      end

      def parse_tasks_json(raw, frames)
        return fallback_tasks(frames) if raw.blank?

        data = JSON.parse(raw)
        tasks = data["tasks"] || data["items"]
        return fallback_tasks(frames) unless tasks.is_a?(Array)

        tasks.filter_map do |t|
          next unless t.is_a?(Hash)

          title = t["title"].to_s.strip
          desc = t["description"].to_s.strip
          next if title.blank?

          { title: title.truncate(255), description: desc.presence }
        end.presence || fallback_tasks(frames)
      rescue JSON::ParserError
        data = extract_json_object(raw)
        tasks = data&.fetch("tasks", nil) || data&.fetch("items", nil)
        return fallback_tasks(frames) unless tasks.is_a?(Array)

        tasks.filter_map do |t|
          next unless t.is_a?(Hash)

          title = t["title"].to_s.strip
          desc = t["description"].to_s.strip
          next if title.blank?

          { title: title.truncate(255), description: desc.presence }
        end.presence || fallback_tasks(frames)
      end

      def fallback_tasks(frames)
        frames.map do |f|
          {
            title: "Implement #{f[:name]} (#{f[:type]})".truncate(255),
            description: "Build the UI and interactions for this Figma #{f[:type].downcase}: \"#{f[:name]}\". Reference path: #{f[:path]}."
          }
        end
      end

      def extract_json_object(raw)
        text = raw.to_s
        start_idx = text.index("{")
        end_idx = text.rindex("}")
        return nil unless start_idx && end_idx && end_idx > start_idx

        JSON.parse(text[start_idx..end_idx])
      rescue JSON::ParserError
        nil
      end
    end
  end
end
