module PromptProtect
  module Providers
    class OpenAIAdapter < BaseAdapter
      def endpoint
        "/v1/chat/completions"
      end

      # OpenAI's request shape is the canonical shape — pass through as-is.
      def build_request
        @payload
      end

      # OpenAI's response shape is already canonical — pass through as-is.
      def parse_response(body)
        body
      end

      def auth_header
        "Bearer #{api_key}"
      end

      def base_url
        ENV.fetch("OPENAI_API_BASE_URL", "https://api.openai.com")
      end

      private

      def api_key
        ENV.fetch("OPENAI_API_KEY") { raise KeyError, "OPENAI_API_KEY is not set" }
      end
    end
  end
end
