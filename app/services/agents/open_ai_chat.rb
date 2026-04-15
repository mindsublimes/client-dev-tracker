# frozen_string_literal: true

module Agents
  module OpenAiChat
    class Error < StandardError; end

    class << self
      def json_content!(messages:, max_tokens: 4096)
        raw = chat_raw!(messages:, max_tokens:, response_format: { type: "json_object" })
        raise Error, "Empty model response" if raw.blank?

        raw
      end

      def text_content!(messages:, max_tokens: 4096)
        chat_raw!(messages:, max_tokens:, response_format: nil)
      end

      private

      def chat_raw!(messages:, max_tokens:, response_format:)
        token = ENV["OPENAI_API_KEY"].presence || ENV["OPENAI_ACCESS_TOKEN"].presence
        raise Error, "Set OPENAI_API_KEY or OPENAI_ACCESS_TOKEN for agent features." if token.blank?

        require "openai" unless defined?(OpenAI)
        raise Error, "ruby-openai gem not available." unless defined?(OpenAI)

        client = OpenAI::Client.new(access_token: token)
        model = ENV.fetch("OPENAI_AGENTS_MODEL", "gpt-4o-mini")
        params = {
          model: model,
          messages: messages,
          max_tokens: max_tokens
        }
        params[:response_format] = response_format if response_format.present?

        response = client.chat(parameters: params)
        response.dig("choices", 0, "message", "content").to_s.strip
      end
    end
  end
end
