module PromptProtect
  module Providers
    # Maps the PROMPT_PROTECT_PROVIDER env var to its adapter class.
    # Defaults to OpenAI.
    #
    # Usage:
    #   Registry.adapter_for("openai")    # => OpenAIAdapter
    #   Registry.adapter_for("anthropic") # => AnthropicAdapter
    #   Registry.adapter_for(nil)         # => OpenAIAdapter (default)
    module Registry
      KNOWN_PROVIDERS = %w[openai anthropic cohere gemini].freeze
      DEFAULT = "openai"

      def self.adapter_for(provider_name)
        name = (provider_name || DEFAULT).to_s.downcase
        case name
        when "openai"    then OpenAIAdapter
        when "anthropic" then AnthropicAdapter
        when "cohere"    then CohereAdapter
        when "gemini"    then GeminiAdapter
        else raise ArgumentError, "Unknown provider '#{name}'. Available: #{KNOWN_PROVIDERS.join(', ')}"
        end
      end

      def self.current
        adapter_for(ENV.fetch("PROMPT_PROTECT_PROVIDER", DEFAULT))
      end
    end
  end
end
