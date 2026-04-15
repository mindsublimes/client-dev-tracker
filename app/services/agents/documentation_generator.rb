# frozen_string_literal: true

module Agents
  # Agent #6 (v1): generate / refresh a living documentation page from project context,
  # agenda items, and lightweight codebase evidence for applicable features.
  class DocumentationGenerator
    class Error < StandardError; end

    SLUG = "living-documentation"
    CODE_FILES_GLOB = "{app,config,lib}/**/*.{rb,erb,js,ts,tsx,css,scss,md}".freeze

    class << self
      def call(project:)
        items = project.agenda_items.includes(:sprint).order(:title).limit(80)
        lines = items.map do |i|
          "- [#{i.status}] #{i.title}: #{i.description.to_s.truncate(200)}"
        end
        code_evidence = collect_code_evidence(project, items)

        raw = Agents::OpenAiChat.text_content!(
          messages: [
            {
              role: "system",
              content: <<~SYS.strip
                You write clear product documentation for stakeholders.
                Output markdown describing major screens/features implied by the task list.
                If information is missing, say what is unknown. No code blocks unless necessary.
              SYS
            },
            {
              role: "user",
              content: <<~USR.strip
                Project: #{project.name}
                Description: #{project.description}

                Tasks:
                #{lines.join("\n").truncate(14_000)}

                Applicable code evidence snippets (best-effort):
                #{code_evidence.truncate(14_000)}
              USR
            }
          ],
          max_tokens: 3500
        )

        raise Error, "Empty documentation from model" if raw.blank?

        page = DocumentationPage.find_or_initialize_by(project_id: project.id, slug: SLUG)
        page.title = "#{project.name} — living documentation"
        page.body = raw
        page.generated_at = Time.current
        page.generation_source = "agent_v1_code_aware"
        page.save!

        { slug: page.slug }
      end

      private

      def collect_code_evidence(project, items)
        keywords = extract_keywords(project, items)
        return "_No clear task keywords found for code mapping._" if keywords.empty?

        snippets = []
        paths = Dir.glob(Rails.root.join(CODE_FILES_GLOB))
                   .select { |p| File.file?(p) }
                   .first(2000)

        paths.each do |path|
          break if snippets.size >= 40

          content = File.read(path)
          next if content.blank?

          lines = content.split("\n")
          match_index = lines.find_index do |line|
            keywords.any? { |kw| line.downcase.include?(kw) }
          end
          next if match_index.nil?

          start = [match_index - 2, 0].max
          finish = [match_index + 2, lines.length - 1].min
          excerpt = lines[start..finish].join("\n")
          relative = Pathname(path).relative_path_from(Rails.root).to_s
          snippets << "File: #{relative}\n#{excerpt}"
        rescue StandardError
          next
        end

        snippets.presence&.join("\n\n---\n\n") || "_No code snippets matched task keywords._"
      end

      def extract_keywords(project, items)
        seed = [project.name, project.description, project.wireframe_outline, project.dev_task_spec_markdown]
        seed += items.map(&:title)
        seed.join(" ")
            .downcase
            .scan(/\b[a-z][a-z0-9_]{3,}\b/)
            .reject { |w| w.in?(stopwords) }
            .tally
            .sort_by { |(_w, c)| -c }
            .map(&:first)
            .first(24)
      end

      def stopwords
        %w[
          this that with from have into screen screens module modules feature features
          design development sprint project client agenda item items review status
          done update updates task tasks
        ]
      end
    end
  end
end
