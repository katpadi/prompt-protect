require "rails_helper"

RSpec.describe PromptProtect::Providers::Registry do
  describe ".adapter_for" do
    it "returns OpenAIAdapter for 'openai'" do
      expect(described_class.adapter_for("openai")).to eq(PromptProtect::Providers::OpenAIAdapter)
    end

    it "returns AnthropicAdapter for 'anthropic'" do
      expect(described_class.adapter_for("anthropic")).to eq(PromptProtect::Providers::AnthropicAdapter)
    end

    it "returns CohereAdapter for 'cohere'" do
      expect(described_class.adapter_for("cohere")).to eq(PromptProtect::Providers::CohereAdapter)
    end

    it "is case-insensitive" do
      expect(described_class.adapter_for("OpenAI")).to eq(PromptProtect::Providers::OpenAIAdapter)
    end

    it "defaults to OpenAIAdapter when nil" do
      expect(described_class.adapter_for(nil)).to eq(PromptProtect::Providers::OpenAIAdapter)
    end

    it "raises ArgumentError for unknown providers" do
      expect { described_class.adapter_for("gemini") }
        .to raise_error(ArgumentError, /Unknown provider/)
    end
  end

  describe ".current" do
    it "returns OpenAIAdapter by default" do
      expect(described_class.current).to eq(PromptProtect::Providers::OpenAIAdapter)
    end

    it "reads PROMPT_PROTECT_PROVIDER env var" do
      allow(ENV).to receive(:fetch).with("PROMPT_PROTECT_PROVIDER", "openai").and_return("anthropic")
      expect(described_class.current).to eq(PromptProtect::Providers::AnthropicAdapter)
    end
  end
end
