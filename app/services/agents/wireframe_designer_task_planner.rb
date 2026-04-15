# frozen_string_literal: true

module Agents
  # Agent #1: from wireframe outline (+ optional text uploads), create designer-facing agenda items
  # with per-screen checklist stored in `checklist` and mirrored in description.
  class WireframeDesignerTaskPlanner
    class Error < StandardError; end

    class << self
      def call(project:, sprint:, acting_user: nil)
        raise Error, "Mark design payment received on the project before running this agent." if project.design_payment_received_at.blank?

        bundle = wireframe_text_bundle(project)
        raise Error, "Add a wireframe outline (markdown) or attach .txt/.md wireframe files." if bundle.blank?

        raw = Agents::OpenAiChat.json_content!(
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt(project, bundle) }
          ],
          max_tokens: 4096
        )

        screens = parse_screens!(raw)
        created = create_items!(project:, sprint:, screens:, acting_user:)
        { created_count: created.size, titles: created.map(&:title) }
      end

      def wireframe_text_bundle(project)
        parts = [project.wireframe_outline.to_s.strip]
        project.wireframe_files.each do |file|
          next unless file.content_type.to_s.match?(/\Atext\//)

          parts << file.download.force_encoding("UTF-8")
        rescue StandardError => e
          Rails.logger.warn("[WireframeDesignerTaskPlanner] skip file #{file.filename}: #{e.message}")
        end
        parts.compact_blank.join("\n\n---\n\n")
      end

      private

      def system_prompt
        <<~TEXT.squish
          You are a delivery lead. Output JSON only with shape:
          {"screens":[{"title":"short agenda title per screen or feature area",
          "checklist":["concrete designer sub-task","..."],"notes":"optional context for designer"}]}.
          Titles must be unique and implementation-neutral (design work, not dev).
          Checklist items are actionable for a human designer (layout, states, components, accessibility).
        TEXT
      end

      def user_prompt(project, bundle)
        <<~TEXT.strip
          Project: #{project.name}
          Client context: #{project.description.to_s.truncate(2000)}

          Wireframe / specification bundle:
          #{bundle.truncate(25_000)}
        TEXT
      end

      def parse_screens!(raw)
        data =
          begin
            JSON.parse(raw)
          rescue JSON::ParserError
            raise Error, "Model returned invalid JSON."
          end
        screens = data["screens"] || data["items"]
        raise Error, "Model JSON missing screens[]" unless screens.is_a?(Array) && screens.any?

        screens.filter_map do |h|
          next unless h.is_a?(Hash)

          title = h["title"].to_s.strip
          next if title.blank?

          checklist = Array(h["checklist"]).map(&:to_s).map(&:strip).reject(&:blank?)
          notes = h["notes"].to_s.strip
          { title: title.truncate(250), checklist: checklist, notes: notes }
        end
      end

      def create_items!(project:, sprint:, screens:, acting_user:)
        screens.map do |row|
          desc_parts = []
          desc_parts << row[:notes] if row[:notes].present?
          if row[:checklist].any?
            desc_parts << "## Designer checklist"
            row[:checklist].each { |c| desc_parts << "- [ ] #{c}" }
          end
          description = desc_parts.join("\n\n").presence

          AgendaItem.create!(
            client_id: project.client_id,
            project_id: project.id,
            sprint_id: sprint.id,
            title: row[:title],
            description: description,
            checklist: row[:checklist],
            agent_source: "wireframe_agent",
            work_stream: :sprint,
            status: :backlog,
            priority_level: :normal,
            complexity: 3,
            due_on: Date.current + 14.days
          ).tap do |item|
            ActivityLogger.log_creation(item, acting_user) if acting_user
          end
        end
      end
    end
  end
end
