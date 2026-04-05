module PromptProtect
  module Providers
    # Cohere adapter — not yet implemented.
    #
    # Differences from OpenAI:
    #   - Endpoint:   POST /v2/chat
    #   - Auth:       Bearer token (Authorization header)
    #   - Request:    { model:, messages: [{ role:, content: }] }
    #                 role values: "user" | "assistant" | "system" (same as OpenAI)
    #   - Response:   { message: { role: "assistant", content: [{ type: "text", text: "..." }] } }
    #
    # TODO (V3):
    #   - Map Cohere response message.content[] back to canonical choices[]
    #   - Handle Cohere-specific error shapes and finish_reason values
    #   - Add COHERE_API_KEY env var support
    class CohereAdapter < BaseAdapter
      def endpoint
        raise NotImplementedError, "CohereAdapter is not yet implemented"
      end

      def build_request
        raise NotImplementedError, "CohereAdapter is not yet implemented"
      end

      def parse_response(body)
        raise NotImplementedError, "CohereAdapter is not yet implemented"
      end

      def auth_header
        raise NotImplementedError, "CohereAdapter is not yet implemented"
      end

      def base_url
        ENV.fetch("COHERE_API_BASE_URL", "https://api.cohere.com")
      end
    end
  end
end
