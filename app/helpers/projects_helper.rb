# frozen_string_literal: true

module ProjectsHelper
  # Always use the main Make entry so users don’t reopen an old /make/{file} URL from the DB.
  FIGMA_MAKE_ENTRY_URL = "https://www.figma.com/make".freeze

  def figma_make_open_url
    FIGMA_MAKE_ENTRY_URL
  end

  def project_figma_file_open_url(project)
    key = project&.figma_file_key.to_s.strip
    return if key.blank?

    "https://www.figma.com/design/#{key}"
  end
end
