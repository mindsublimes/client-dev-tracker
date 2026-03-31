# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "base64"

module Figma
  # OAuth 2 for Figma REST API. Client ID/secret live in ENV only — never in code.
  #
  # FIGMA_CLIENT_ID, FIGMA_CLIENT_SECRET, FIGMA_OAUTH_REDIRECT_URI (must match app config in Figma)
  # Scopes: https://developers.figma.com/docs/rest-api/scopes/
  class Oauth
    AUTH_URL = "https://www.figma.com/oauth"
    TOKEN_URL = "https://api.figma.com/v1/oauth/token"
    REFRESH_URL = "https://api.figma.com/v1/oauth/refresh"
    DEFAULT_SCOPE = "file_content:read"

    class Error < StandardError; end

    class << self
      def configured?
        client_id.present? && client_secret.present? && redirect_uri.present?
      end

      def authorization_url(state:, scope: nil)
        raise Error, "Figma OAuth is not configured. Set FIGMA_CLIENT_ID, FIGMA_CLIENT_SECRET, and FIGMA_OAUTH_REDIRECT_URI." unless configured?

        q = {
          client_id: client_id,
          redirect_uri: redirect_uri,
          scope: scope || ENV.fetch("FIGMA_OAUTH_SCOPE", DEFAULT_SCOPE),
          state: state,
          response_type: "code"
        }
        "#{AUTH_URL}?#{URI.encode_www_form(q)}"
      end

      # @return [Hash] parsed JSON (access_token, refresh_token, expires_in, ...)
      def exchange_code(code:)
        raise Error, "Figma OAuth is not configured." unless configured?

        post_form(TOKEN_URL, {
                    redirect_uri: redirect_uri,
                    code: code,
                    grant_type: "authorization_code"
                  })
      end

      # @return [Hash] parsed JSON
      def refresh(refresh_token:)
        raise Error, "Figma OAuth is not configured." unless configured?

        post_form(REFRESH_URL, {
                    refresh_token: refresh_token
                  })
      end

      private

      def client_id
        ENV["FIGMA_CLIENT_ID"].to_s.strip
      end

      def client_secret
        ENV["FIGMA_CLIENT_SECRET"].to_s.strip
      end

      def redirect_uri
        ENV["FIGMA_OAUTH_REDIRECT_URI"].to_s.strip
      end

      def post_form(url, body_hash)
        uri = URI(url)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req["Authorization"] = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"
        req.body = URI.encode_www_form(body_hash)

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60, open_timeout: 15) do |http|
          http.request(req)
        end

        data =
          begin
            JSON.parse(res.body)
          rescue JSON::ParserError
            raise Error, "Figma OAuth invalid response (#{res.code}): #{res.body.to_s.truncate(200)}"
          end
        return data if res.code.to_i == 200

        msg = data["error_description"].presence || data["message"].presence || data["error"].presence || res.body.to_s.truncate(200)
        raise Error, "Figma OAuth error (#{res.code}): #{msg}"
      end
    end
  end
end
