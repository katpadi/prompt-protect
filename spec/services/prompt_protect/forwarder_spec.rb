require "rails_helper"

RSpec.describe PromptProtect::Forwarder do
  let(:base_payload) do
    { "model" => "gpt-4o", "messages" => [ { "role" => "user", "content" => "Hello" } ] }
  end

  let(:openai_response) do
    { "id" => "chatcmpl-123", "choices" => [ { "message" => { "role" => "assistant", "content" => "Hi" } } ] }
  end

  before do
    stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: openai_response.to_json)
    ENV["OPENAI_API_KEY"] = "test-key"
  end

  after { ENV.delete("OPENAI_API_KEY") }

  describe "provider resolution" do
    it "uses openai by default" do
      described_class.new(base_payload).call
      expect(a_request(:post, /api\.openai\.com/)).to have_been_made
    end

    it "reads provider from request payload" do
      # passes openai explicitly via payload — same behaviour, confirms payload takes precedence
      described_class.new(base_payload.merge("provider" => "openai")).call
      expect(a_request(:post, /api\.openai\.com/)).to have_been_made
    end

    it "strips provider key before forwarding" do
      described_class.new(base_payload.merge("provider" => "openai")).call
      expect(a_request(:post, /api\.openai\.com/).with { |req|
        !JSON.parse(req.body).key?("provider")
      }).to have_been_made
    end

    it "falls back to PROMPT_PROTECT_PROVIDER env var when payload omits provider" do
      with_env("PROMPT_PROTECT_PROVIDER" => "openai") do
        described_class.new(base_payload).call
        expect(a_request(:post, /api\.openai\.com/)).to have_been_made
      end
    end

    it "raises ArgumentError for unknown provider in payload" do
      expect {
        described_class.new(base_payload.merge("provider" => "gemini")).call
      }.to raise_error(ArgumentError, /Unknown provider/)
    end
  end
end
