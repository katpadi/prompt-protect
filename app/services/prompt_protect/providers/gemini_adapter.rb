module PromptProtect
  module Providers
    # Adapter for Google Gemini using the native generateContent API.
    # Translates the canonical OpenAI message format to Gemini's request/response shape.
    #
    # Docs: https://ai.google.dev/gemini-api/docs/text-generation
    class GeminiAdapter < BaseAdapter
      def endpoint
        model = @payload["model"] || "gemini-2.0-flash"
        "/v1beta/models/#{model}:generateContent"
      end

      def base_url
        ENV.fetch("GEMINI_API_BASE_URL", "https://generativelanguage.googleapis.com")
      end

      def request_headers
        { "x-goog-api-key" => api_key, "Content-Type" => "application/json" }
      end

      def build_request
        messages = @payload["messages"] || []
        system_msg    = messages.find { |m| m["role"] == "system" }
        content_msgs  = messages.reject { |m| m["role"] == "system" }

        req = {
          "contents" => content_msgs.map do |m|
            {
              "role"  => m["role"] == "assistant" ? "model" : "user",
              "parts" => [ { "text" => m["content"].to_s } ]
            }
          end
        }

        if system_msg
          req["systemInstruction"] = { "parts" => [ { "text" => system_msg["content"].to_s } ] }
        end

        req
      end

      def parse_response(body)
        candidate = body.dig("candidates", 0)
        text      = candidate&.dig("content", "parts", 0, "text").to_s
        usage     = body["usageMetadata"] || {}

        finish_reason =
          case candidate&.dig("finishReason")
          when "STOP"         then "stop"
          when "MAX_TOKENS"   then "length"
          when "SAFETY"       then "content_filter"
          else "stop"
          end

        {
          "id"      => "gemini-#{SecureRandom.hex(8)}",
          "object"  => "chat.completion",
          "model"   => @payload["model"],
          "choices" => [
            {
              "index"         => 0,
              "message"       => { "role" => "assistant", "content" => text },
              "finish_reason" => finish_reason
            }
          ],
          "usage" => {
            "prompt_tokens"     => usage["promptTokenCount"] || 0,
            "completion_tokens" => usage["candidatesTokenCount"] || 0,
            "total_tokens"      => usage["totalTokenCount"] || 0
          }
        }
      end

      # Satisfies the BaseAdapter interface — not used (request_headers is overridden).
      def auth_header
        "Bearer #{api_key}"
      end

      private

      def api_key
        ENV.fetch("GEMINI_API_KEY") { raise KeyError, "GEMINI_API_KEY is not set" }
      end
    end
  end
end
