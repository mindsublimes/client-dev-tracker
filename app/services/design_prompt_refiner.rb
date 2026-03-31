# Turns a markdown app description (design brief) into a concise prompt suitable for
# Uizard Autodesigner, Figma Make, or similar tools. Uses OpenAI when OPENAI_API_KEY
# is set and the openai gem is available; otherwise returns the brief as-is.
class DesignPromptRefiner
  class << self
    def call(design_brief)
      call_with_meta(design_brief)[:text]
    end

    def call_with_meta(design_brief)
      return { text: "", source: :fallback, error: nil } if design_brief.blank?

      if openai_available?
        refined = refine_with_openai(design_brief)
        return { text: refined, source: :openai, error: nil } if refined.present?
      else
        return { text: fallback_prompt(design_brief), source: :fallback, error: "OpenAI key not loaded or gem unavailable" }
      end
    rescue StandardError => e
      detail = extract_openai_error_detail(e)
      Rails.logger.warn("[DesignPromptRefiner] OpenAI refinement failed: #{e.class}: #{detail}")
      { text: fallback_prompt(design_brief), source: :fallback, error: detail }
    end

    def openai_available?
      return false unless openai_token.present?
      require "openai" unless defined?(OpenAI)
      defined?(OpenAI)
    rescue LoadError
      false
    end

    private

    def openai_token
      ENV["OPENAI_API_KEY"].presence || ENV["OPENAI_ACCESS_TOKEN"].presence
    end

    def refine_with_openai(design_brief)
      client = OpenAI::Client.new(access_token: openai_token)
      params_base = {
        messages: [
          {
            role: "system",
            content: <<~SYSTEM.strip
              You are a UX copywriter. Given a markdown description of an app or product,
              output a single, concise design prompt (2-4 sentences) suitable for pasting
              into Uizard Autodesigner or Figma Make. Include: app purpose, main screens
              or sections, and key UI elements (e.g. navigation, forms, buttons). No
              preamble—only the prompt text.
            SYSTEM
          },
          { role: "user", content: design_brief }
        ],
        max_tokens: 400
      }

      last_error = nil
      model_candidates_for(client).each do |model|
        response = client.chat(parameters: params_base.merge(model: model))
        text = response.dig("choices", 0, "message", "content")
        return text.to_s.strip if text.present?
      rescue StandardError => e
        last_error = e
        raise e unless model_retryable?(e)

        Rails.logger.info("[DesignPromptRefiner] Model #{model} failed, trying next: #{extract_openai_error_detail(e)}")
      end

      raise last_error if last_error

      ""
    end

    # Preference order first, then any chat-capable model IDs returned for this API key / project.
    def model_candidates_for(client)
      from_env = ENV["OPENAI_DESIGN_MODEL"].to_s.strip.presence
      extras = ENV["OPENAI_DESIGN_MODEL_FALLBACKS"].to_s.split(",").map(&:strip).reject(&:blank?)
      defaults = %w[
        gpt-4.1-mini
        gpt-4.1-nano
        gpt-4.1
        gpt-4o-mini
        gpt-4o
        gpt-4-turbo
        gpt-3.5-turbo
        o4-mini
        o3-mini
      ]
      discovered = discover_chat_model_ids(client)
      ([from_env] + extras + defaults + discovered).compact.uniq
    end

    def discover_chat_model_ids(client)
      res = client.models.list
      data =
        case res
        when Hash
          res["data"] || res[:data]
        else
          nil
        end
      return [] unless data.is_a?(Array)

      ids = data.filter_map do |m|
        next unless m.is_a?(Hash)

        m["id"] || m[:id]
      end.compact
      chat_like = ids.select { |id| chat_completion_model_id?(id) }
      deny = ENV["OPENAI_DESIGN_MODEL_DENYLIST"].to_s.split(",").map(&:strip).reject(&:blank?)
      chat_like - deny
    rescue StandardError => e
      Rails.logger.warn("[DesignPromptRefiner] models.list skipped: #{e.class}: #{e.message}")
      []
    end

    def chat_completion_model_id?(id)
      return false if id.blank?
      return false if id.match?(/embed|realtime|audio|tts|whisper|instruct|image|moderation/i)

      id.match?(/\A(gpt-|o\d)/i)
    end

    def model_retryable?(error)
      msg = extract_openai_error_detail(error).downcase
      # OpenAI uses both "does not have access" (project) and "you do not have access" (wording).
      msg.include?("does not have access") ||
        msg.include?("do not have access") ||
        msg.include?("model_not_found") ||
        msg.include?("invalid_model") ||
        msg.include?("model_not_found_error") ||
        msg.include?("does not exist") ||
        msg.include?("incorrect model id") ||
        msg.include?("no such model")
    end

    def fallback_prompt(design_brief)
      design_brief.to_s.strip
    end

    def extract_openai_error_detail(error)
      return error.message.to_s if !error.respond_to?(:response) || error.response.blank?

      body = error.response[:body]
      parsed =
        case body
        when String
          JSON.parse(body) rescue nil
        when Hash
          body
        else
          nil
        end
      api_message = parsed&.dig("error", "message")
      api_message.presence || error.message.to_s
    end
  end
end
