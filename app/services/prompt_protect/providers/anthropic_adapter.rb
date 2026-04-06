module PromptProtect
  module Providers
    # Anthropic (Claude) adapter.
    #
    # Translates the canonical OpenAI-shaped payload to Anthropic's Messages API
    # and maps the response back to canonical shape.
    #
    # Key differences handled here:
    #   - Auth:       x-api-key + anthropic-version headers (not Bearer)
    #   - Endpoint:   POST /v1/messages
    #   - System msg: extracted from messages[] into top-level "system" field
    #   - max_tokens: required by Anthropic — defaults to 4096 if omitted
    #   - Response:   content[].text → choices[].message.content
    #   - Usage:      input_tokens/output_tokens → prompt_tokens/completion_tokens
    class AnthropicAdapter < BaseAdapter
      ANTHROPIC_VERSION = "2023-06-01"
      DEFAULT_MAX_TOKENS = 4096

      STOP_REASON_MAP = {
        "end_turn"      => "stop",
        "stop_sequence" => "stop",
        "max_tokens"    => "length",
        "tool_use"      => "tool_calls"
      }.freeze

      def endpoint
        "/v1/messages"
      end

      def base_url
        ENV.fetch("ANTHROPIC_API_BASE_URL", "https://api.anthropic.com")
      end

      # Anthropic uses x-api-key + anthropic-version instead of Authorization.
      def request_headers
        {
          "x-api-key"         => api_key,
          "anthropic-version" => ANTHROPIC_VERSION
        }
      end

      # auth_header is unused — request_headers is the authoritative method.
      def auth_header
        raise NotImplementedError, "AnthropicAdapter uses request_headers, not auth_header"
      end

      # Translate canonical OpenAI payload → Anthropic Messages API request body.
      #
      # - Extracts system messages into the top-level "system" field
      # - Keeps only user/assistant messages in "messages"
      # - Maps "stop" → "stop_sequences"
      # - Ensures max_tokens is present (required by Anthropic)
      def build_request
        messages = @payload.fetch("messages", [])
        system_content = extract_system(messages)
        conversation   = messages.reject { |m| m["role"] == "system" }

        request = {
          "model"      => @payload["model"],
          "messages"   => conversation,
          "max_tokens" => @payload.fetch("max_tokens", DEFAULT_MAX_TOKENS)
        }

        request["system"] = system_content if system_content
        request["temperature"]    = @payload["temperature"]    if @payload.key?("temperature")
        request["top_p"]          = @payload["top_p"]          if @payload.key?("top_p")
        request["stop_sequences"] = Array(@payload["stop"])    if @payload.key?("stop")
        request["stream"]         = @payload["stream"]         if @payload.key?("stream")

        request
      end

      # Translate Anthropic response → canonical OpenAI shape.
      #
      # Anthropic:  { content: [{ type: "text", text: "..." }], stop_reason:, usage: { input_tokens:, output_tokens: } }
      # Canonical:  { choices: [{ message: { role:, content: }, finish_reason: }], usage: { prompt_tokens:, completion_tokens:, total_tokens: } }
      def parse_response(body)
        text         = extract_text(body)
        finish       = STOP_REASON_MAP.fetch(body["stop_reason"].to_s, "stop")
        input_tokens = body.dig("usage", "input_tokens").to_i
        output_tokens = body.dig("usage", "output_tokens").to_i

        {
          "id"      => body["id"],
          "object"  => "chat.completion",
          "created" => Time.now.to_i,
          "model"   => body["model"],
          "choices" => [
            {
              "index"        => 0,
              "message"      => { "role" => "assistant", "content" => text },
              "finish_reason" => finish
            }
          ],
          "usage" => {
            "prompt_tokens"     => input_tokens,
            "completion_tokens" => output_tokens,
            "total_tokens"      => input_tokens + output_tokens
          }
        }
      end

      private

      def api_key
        ENV.fetch("ANTHROPIC_API_KEY") { raise KeyError, "ANTHROPIC_API_KEY is not set" }
      end

      # Join multiple system messages with a newline (uncommon but valid in OpenAI format).
      def extract_system(messages)
        parts = messages.select { |m| m["role"] == "system" }.map { |m| m["content"] }
        parts.empty? ? nil : parts.join("\n")
      end

      # Concatenate all text-type content blocks in the response.
      def extract_text(body)
        Array(body["content"])
          .select { |block| block["type"] == "text" }
          .map { |block| block["text"] }
          .join
      end
    end
  end
end
