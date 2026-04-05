module PromptProtect
  module Providers
    # Interface all provider adapters must implement.
    #
    # Responsibilities:
    #   - build_request  — translate canonical payload → provider-specific body
    #   - parse_response — translate provider response → canonical shape
    #   - endpoint       — provider API path
    #   - auth_header    — provider-specific Authorization header value
    #   - base_url       — provider base URL (from env or default)
    class BaseAdapter
      # @param payload [Hash] canonical OpenAI-shaped request payload
      def initialize(payload)
        @payload = payload
      end

      # Returns the full URL path for the chat/completion endpoint.
      # @return [String]
      def endpoint
        raise NotImplementedError, "#{self.class} must implement #endpoint"
      end

      # Translates the canonical payload into the provider's expected request body.
      # @return [Hash]
      def build_request
        raise NotImplementedError, "#{self.class} must implement #build_request"
      end

      # Translates the provider's response body into the canonical shape:
      #   { "choices" => [{ "message" => { "role" => "...", "content" => "..." } }] }
      # @param body [Hash] parsed provider response
      # @return [Hash] canonical response
      def parse_response(body)
        raise NotImplementedError, "#{self.class} must implement #parse_response"
      end

      # Returns the value for the Authorization (or equivalent) header.
      # @return [String]
      def auth_header
        raise NotImplementedError, "#{self.class} must implement #auth_header"
      end

      # Base URL for the provider API.
      # @return [String]
      def base_url
        raise NotImplementedError, "#{self.class} must implement #base_url"
      end
    end
  end
end
