require "rails_helper"

RSpec.describe PromptProtect::Providers::GeminiAdapter do
  let(:payload) do
    {
      "model"    => "gemini-2.0-flash",
      "messages" => [
        { "role" => "system",    "content" => "You are a helpful assistant." },
        { "role" => "user",      "content" => "Hello!" },
        { "role" => "assistant", "content" => "Hi there!" },
        { "role" => "user",      "content" => "How are you?" }
      ]
    }
  end

  subject(:adapter) { described_class.new(payload) }

  around { |ex| with_env("GEMINI_API_KEY" => "test-gemini-key") { ex.run } }

  describe "#endpoint" do
    it "builds a model-specific generateContent path" do
      expect(adapter.endpoint).to eq("/v1beta/models/gemini-2.0-flash:generateContent")
    end

    it "defaults to gemini-2.0-flash when model is missing" do
      adapter = described_class.new({})
      expect(adapter.endpoint).to eq("/v1beta/models/gemini-2.0-flash:generateContent")
    end
  end

  describe "#base_url" do
    it "defaults to the Gemini API base URL" do
      expect(adapter.base_url).to eq("https://generativelanguage.googleapis.com")
    end

    it "can be overridden via GEMINI_API_BASE_URL" do
      with_env("GEMINI_API_BASE_URL" => "http://localhost:9999") do
        expect(adapter.base_url).to eq("http://localhost:9999")
      end
    end
  end

  describe "#request_headers" do
    it "sends the API key as x-goog-api-key" do
      expect(adapter.request_headers["x-goog-api-key"]).to eq("test-gemini-key")
    end
  end

  describe "#build_request" do
    subject(:request) { adapter.build_request }

    it "extracts system message into systemInstruction" do
      expect(request["systemInstruction"]).to eq(
        "parts" => [ { "text" => "You are a helpful assistant." } ]
      )
    end

    it "maps user messages to Gemini contents with role user" do
      user_entries = request["contents"].select { |c| c["role"] == "user" }
      expect(user_entries.map { |c| c.dig("parts", 0, "text") }).to include("Hello!", "How are you?")
    end

    it "maps assistant messages to Gemini contents with role model" do
      model_entries = request["contents"].select { |c| c["role"] == "model" }
      expect(model_entries.first&.dig("parts", 0, "text")).to eq("Hi there!")
    end

    it "excludes system messages from contents" do
      roles = request["contents"].map { |c| c["role"] }
      expect(roles).not_to include("system")
    end

    context "without a system message" do
      let(:payload) { { "model" => "gemini-2.0-flash", "messages" => [ { "role" => "user", "content" => "Hi" } ] } }

      it "omits systemInstruction" do
        expect(request).not_to have_key("systemInstruction")
      end
    end
  end

  describe "#parse_response" do
    let(:gemini_body) do
      {
        "candidates" => [
          {
            "content"      => { "parts" => [ { "text" => "Hello!" } ], "role" => "model" },
            "finishReason" => "STOP",
            "index"        => 0
          }
        ],
        "usageMetadata" => {
          "promptTokenCount"     => 10,
          "candidatesTokenCount" => 5,
          "totalTokenCount"      => 15
        }
      }
    end

    subject(:parsed) { adapter.parse_response(gemini_body) }

    it "returns object chat.completion" do
      expect(parsed["object"]).to eq("chat.completion")
    end

    it "maps content text into choices[0].message.content" do
      expect(parsed.dig("choices", 0, "message", "content")).to eq("Hello!")
    end

    it "sets role to assistant" do
      expect(parsed.dig("choices", 0, "message", "role")).to eq("assistant")
    end

    it "maps STOP to finish_reason stop" do
      expect(parsed.dig("choices", 0, "finish_reason")).to eq("stop")
    end

    it "maps MAX_TOKENS to finish_reason length" do
      body = gemini_body.deep_merge("candidates" => [ { "finishReason" => "MAX_TOKENS" } ])
      expect(adapter.parse_response(body).dig("choices", 0, "finish_reason")).to eq("length")
    end

    it "maps token counts to OpenAI usage shape" do
      expect(parsed["usage"]).to eq(
        "prompt_tokens"     => 10,
        "completion_tokens" => 5,
        "total_tokens"      => 15
      )
    end
  end

  describe "registry" do
    it "resolves gemini to GeminiAdapter" do
      expect(PromptProtect::Providers::Registry.adapter_for("gemini")).to eq(described_class)
    end
  end

  describe "missing API key" do
    it "raises KeyError when GEMINI_API_KEY is not set" do
      with_env("GEMINI_API_KEY" => nil) do
        expect { adapter.request_headers }.to raise_error(KeyError, /GEMINI_API_KEY/)
      end
    end
  end
end
