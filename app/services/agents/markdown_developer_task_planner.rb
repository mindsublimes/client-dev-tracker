# frozen_string_literal: true

module Agents
  # Agent #3: from the project's development task markdown spec, create developer agenda items.
  class MarkdownDeveloperTaskPlanner
    class Error < StandardError; end

    class << self
      def call(project:, sprint:, acting_user: nil, require_sprint_payment: true)
        if require_sprint_payment && sprint.development_payment_received_at.blank?
          raise Error, "Mark development payment received on the sprint (internal) before running this agent."
        end

        md = project.dev_task_spec_markdown.to_s.strip
        raise Error, "Paste the development breakdown into “Development task spec (markdown)” on the project first." if md.blank?

        raw = Agents::OpenAiChat.json_content!(
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt(project, md) }
          ],
          max_tokens: 4096
        )

        tasks = parse_tasks!(raw)
        created = create_items!(project:, sprint:, tasks:, acting_user:)
        { created_count: created.size, titles: created.map(&:title) }
      end

      private

      def system_prompt
        <<~TEXT.squish
          You are a tech lead. Output JSON only with shape:
          {"tasks":[{"title":"concise dev task","checklist":["sub-step or acceptance criterion","..."],"notes":"optional"}]}.
          Tasks should map to modules/screens/features from the spec. Titles must be unique.
        TEXT
      end

      def user_prompt(project, md)
        <<~TEXT.strip
          Project: #{project.name}
          Context: #{project.description.to_s.truncate(1500)}

          Development specification (markdown):
          #{md.truncate(30_000)}
        TEXT
      end

      def parse_tasks!(raw)
        data =
          begin
            JSON.parse(raw)
          rescue JSON::ParserError
            raise Error, "Model returned invalid JSON."
          end
        tasks = data["tasks"] || data["items"]
        raise Error, "Model JSON missing tasks[]" unless tasks.is_a?(Array) && tasks.any?

        tasks.filter_map do |h|
          next unless h.is_a?(Hash)

          title = h["title"].to_s.strip
          next if title.blank?

          checklist = Array(h["checklist"]).map(&:to_s).map(&:strip).reject(&:blank?)
          notes = h["notes"].to_s.strip
          { title: title.truncate(250), checklist: checklist, notes: notes }
        end
      end

      def create_items!(project:, sprint:, tasks:, acting_user:)
        tasks.map do |row|
          desc_parts = []
          desc_parts << row[:notes] if row[:notes].present?
          if row[:checklist].any?
            desc_parts << "## Development checklist"
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
            agent_source: "dev_spec_agent",
            work_stream: :sprint,
            status: :backlog,
            priority_level: :normal,
            complexity: 3,
            due_on: Date.current + 7.days
          ).tap do |item|
            ActivityLogger.log_creation(item, acting_user) if acting_user
          end
        end
      end
    end
  end
end
