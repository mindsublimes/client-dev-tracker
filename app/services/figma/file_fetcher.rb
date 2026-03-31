# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Figma
  # Fetches file JSON from the Figma REST API (same data Dev Mode uses).
  #
  # Authentication (first match wins):
  # 1. Logged-in user's OAuth token (Connect Figma) — Authorization: Bearer
  # 2. FIGMA_ACCESS_TOKEN — personal access token via X-Figma-Token header
  class FileFetcher
    API_BASE = "https://api.figma.com/v1"

    class Error < StandardError; end
    class MissingToken < Error; end
    class Unauthorized < Error; end
    class NotFound < Error; end

    class << self
      # @param user [User, nil] when present, uses stored OAuth token after refresh if needed
      def fetch(file_key, user: nil)
        token, mode = resolve_token!(user)

        key = file_key.to_s.strip
        raise Error, "Invalid Figma file key." if key.blank?

        uri = URI("#{API_BASE}/files/#{key}")
        req = Net::HTTP::Get.new(uri)
        if mode == :bearer
          req["Authorization"] = "Bearer #{token}"
        else
          req["X-Figma-Token"] = token
        end

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120, open_timeout: 30) do |http|
          http.request(req)
        end

        case res.code.to_i
        when 200
          JSON.parse(res.body)
        when 403
          raise Unauthorized, "Figma rejected the token (forbidden). Re-connect Figma or check file access and scopes (file_content:read)."
        when 404
          raise NotFound, "Figma file not found or your account cannot access it."
        else
          body = res.body.to_s.truncate(300)
          raise Error, "Figma API error #{res.code}: #{body}"
        end
      end

      private

      def resolve_token!(user)
        if user.respond_to?(:figma_access_token) && user.figma_access_token.present?
          user.ensure_figma_access_token_fresh!
          return [user.figma_access_token, :bearer]
        end

        pat = ENV["FIGMA_ACCESS_TOKEN"].to_s.strip
        return [pat, :personal] if pat.present?

        msg = if Figma::Oauth.configured?
                "Connect your Figma account (button on this page) or set FIGMA_ACCESS_TOKEN for a personal access token."
              else
                "Set FIGMA_CLIENT_ID, FIGMA_CLIENT_SECRET, and FIGMA_OAUTH_REDIRECT_URI to use “Connect Figma”, or set FIGMA_ACCESS_TOKEN."
              end
        raise MissingToken, msg
      end
    end
  end
end
