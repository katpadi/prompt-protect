module PromptProtect
  module Providers
    # Anthropic (Claude) adapter — not yet implemented.
    #
    # Differences from OpenAI:
    #   - Endpoint:   POST /v1/messages
    #   - Auth:       x-api-key header (not Bearer)
    #   - Request:    { model:, max_tokens:, messages: [{ role:, content: }] }
    #   - Response:   { content: [{ type: "text", text: "..." }], role: "assistant", ... }
    #
    # TODO (V3):
    #   - Map canonical messages[] → Anthropic messages[] (system prompt handling differs)
    #   - Map Anthropic response content[] back to canonical choices[]
    #   - Handle Anthropic-specific error shapes
    #   - Add ANTHROPIC_API_KEY env var support
    class AnthropicAdapter < BaseAdapter
      def endpoint
        raise NotImplementedError, "AnthropicAdapter is not yet implemented"
      end

      def build_request
        raise NotImplementedError, "AnthropicAdapter is not yet implemented"
      end

      def parse_response(body)
        raise NotImplementedError, "AnthropicAdapter is not yet implemented"
      end

      def auth_header
        raise NotImplementedError, "AnthropicAdapter is not yet implemented"
      end

      def base_url
        ENV.fetch("ANTHROPIC_API_BASE_URL", "https://api.anthropic.com")
      end
    end
  end
end
