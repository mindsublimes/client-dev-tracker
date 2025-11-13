module AttachmentsHelper
  def attachment_thumbnail_url(file, resize_to_limit: [150, 150])
    return unless file
    return url_for(file) unless file.variable?

    return generate_variant_url(file, resize_to_limit) if mini_magick_cli_available?

    url_for(file)
  rescue MiniMagick::Error, MiniMagick::Invalid, ActiveStorage::InvariableError => e
    Rails.logger.warn("Attachment thumbnail fallback: #{e.class} - #{e.message}")
    url_for(file)
  end

  private

  def generate_variant_url(file, resize_to_limit)
    representation = file.representation(resize_to_limit:)
    representation.processed
    url_for(representation)
  end

  def mini_magick_cli_available?
    return @_mini_magick_cli_available unless @_mini_magick_cli_available.nil?
    return @_mini_magick_cli_available = false unless defined?(MiniMagick)

    command = MiniMagick.imagemagick7? ? 'magick' : 'convert'
    @_mini_magick_cli_available = MiniMagick::Utilities.which(command).present?
  rescue StandardError => e
    Rails.logger.debug("MiniMagick CLI detection failed: #{e.message}")
    @_mini_magick_cli_available = false
  end
end
