# frozen_string_literal: true

module Agents
  # Agent #2: match Figma frames to existing project agenda items; set figma links and leave a short sync note.
  class FigmaAgendaSync
    class Error < StandardError; end

    class << self
      def call(project:, user:)
        key = project.figma_file_key.to_s.strip
        raise Error, "Set a default Figma file key on the project (or use Design → Tasks once to save it)." if key.blank?

        file_json = Figma::FileFetcher.fetch(key, user: user)
        frames = Figma::FrameCollector.collect_from_file(file_json)
        raise Error, "No frames/components found in that Figma file." if frames.blank?

        items = AgendaItem.where(project_id: project.id).includes(:sprint)
        actor = user
        updated = []

        frames.each do |frame|
          next if frame[:name].blank? || frame[:id].blank?

          item = match_item(items, frame[:name])
          next unless item

          url = figma_frame_url(key, frame[:id])
          item.update!(
            figma_screen_url: url,
            figma_node_id: frame[:id],
            agent_source: (item.agent_source.presence || "figma_sync")
          )
          body = <<~MSG.strip
            **Designer agent (Figma sync)** linked this item to frame "#{frame[:name]}" (#{frame[:type]}).
            Path: #{frame[:path]}
          MSG
          AgendaMessage.create!(
            agenda_item: item,
            user: actor,
            body: body,
            kind: :comment
          )
          updated << item.title
        end

        { updated_count: updated.size, titles: updated.uniq }
      end

      private

      def match_item(items, frame_name)
        fn = frame_name.downcase.strip
        items.find { |i| i.title.downcase.strip == fn } ||
          items.find { |i| fn.include?(i.title.downcase.strip) && i.title.length >= 4 } ||
          items.find { |i| i.title.downcase.strip.in?(fn) }
      end

      def figma_frame_url(file_key, node_id)
        encoded = node_id.tr(":", "-")
        "https://www.figma.com/design/#{file_key}/?node-id=#{encoded}"
      end
    end
  end
end
