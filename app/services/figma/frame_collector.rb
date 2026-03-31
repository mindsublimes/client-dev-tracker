# frozen_string_literal: true

module Figma
  # Walks the Figma document tree and collects FRAME / COMPONENT / INSTANCE nodes
  # (and SECTION) for LLM summarization into implementation tasks.
  class FrameCollector
    TARGET_TYPES = %w[FRAME COMPONENT COMPONENT_SET INSTANCE SECTION].freeze
    MAX_NODES = 120

    class << self
      # @param document [Hash] Figma API file payload (full JSON) — uses top-level "document" key
      def collect_from_file(file_json)
        root = file_json["document"]
        return [] unless root.is_a?(Hash)

        out = []
        walk(root, [], out)
        out.first(MAX_NODES)
      end

      private

      def walk(node, path_segments, out)
        return if out.size >= MAX_NODES

        name = node["name"].to_s
        type = node["type"].to_s
        segments = path_segments + [name].reject(&:blank?)

        if TARGET_TYPES.include?(type) && name.present?
          abs = node["absoluteBoundingBox"].is_a?(Hash) ? node["absoluteBoundingBox"] : {}
          constraints = node["constraints"].is_a?(Hash) ? node["constraints"] : {}
          size = if abs["width"].present? && abs["height"].present?
                   "#{abs['width'].round}x#{abs['height'].round}"
                 end

          out << {
            name: name,
            type: type,
            path: segments.join(" › "),
            size: size,
            layout_mode: node["layoutMode"].presence,
            item_spacing: node["itemSpacing"],
            primary_axis_align: node["primaryAxisAlignItems"].presence,
            counter_axis_align: node["counterAxisAlignItems"].presence,
            padding: {
              top: node["paddingTop"],
              right: node["paddingRight"],
              bottom: node["paddingBottom"],
              left: node["paddingLeft"]
            }.compact.presence,
            overflow_direction: node["overflowDirection"].presence,
            constraints: constraints.compact.presence
          }
        end

        Array(node["children"]).each { |child| walk(child, segments, out) }
      end
    end
  end
end
