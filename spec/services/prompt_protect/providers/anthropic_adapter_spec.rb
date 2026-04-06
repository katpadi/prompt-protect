require "rails_helper"

RSpec.describe PromptProtect::Providers::AnthropicAdapter do
  let(:base_payload) do
    {
      "model"    => "claude-3-5-sonnet-20241022",
      "messages" => [
        { "role" => "system",    "content" => "You are a helpful assistant." },
        { "role" => "user",      "content" => "Hello!" },
        { "role" => "assistant", "content" => "Hi there!" },
        { "role" => "user",      "content" => "What's your name?" }
      ],
      "max_tokens"  => 1024,
      "temperature" => 0.7
    }
  end

  subject(:adapter) { described_class.new(base_payload) }

  before { ENV["ANTHROPIC_API_KEY"] = "test-anthropic-key" }
  after  { ENV.delete("ANTHROPIC_API_KEY") }

  describe "#endpoint" do
    it "returns the Anthropic messages endpoint" do
      expect(adapter.endpoint).to eq("/v1/messages")
    end
  end

  describe "#base_url" do
    it "defaults to Anthropic's API URL" do
      expect(adapter.base_url).to eq("https://api.anthropic.com")
    end

    it "reads ANTHROPIC_API_BASE_URL env var" do
      with_env("ANTHROPIC_API_BASE_URL" => "https://custom.anthropic.com") do
        expect(adapter.base_url).to eq("https://custom.anthropic.com")
      end
    end
  end

  describe "#request_headers" do
    it "uses x-api-key instead of Authorization" do
      expect(adapter.request_headers).to include("x-api-key" => "test-anthropic-key")
    end

    it "includes anthropic-version header" do
      expect(adapter.request_headers).to include("anthropic-version" => "2023-06-01")
    end

    it "does not include Authorization header" do
      expect(adapter.request_headers).not_to have_key("Authorization")
    end
  end

  describe "#build_request" do
    subject(:request) { adapter.build_request }

    it "extracts system message into top-level system field" do
      expect(request["system"]).to eq("You are a helpful assistant.")
    end

    it "excludes system messages from the messages array" do
      roles = request["messages"].map { |m| m["role"] }
      expect(roles).not_to include("system")
    end

    it "preserves user and assistant messages in order" do
      expect(request["messages"]).to eq([
        { "role" => "user",      "content" => "Hello!" },
        { "role" => "assistant", "content" => "Hi there!" },
        { "role" => "user",      "content" => "What's your name?" }
      ])
    end

    it "preserves max_tokens from payload" do
      expect(request["max_tokens"]).to eq(1024)
    end

    it "defaults max_tokens to 4096 when not in payload" do
      adapter = described_class.new(base_payload.except("max_tokens"))
      expect(adapter.build_request["max_tokens"]).to eq(4096)
    end

    it "preserves temperature" do
      expect(request["temperature"]).to eq(0.7)
    end

    it "omits system key when no system message is present" do
      payload = base_payload.merge("messages" => [ { "role" => "user", "content" => "Hi" } ])
      expect(described_class.new(payload).build_request).not_to have_key("system")
    end

    it "joins multiple system messages with a newline" do
      payload = base_payload.merge("messages" => [
        { "role" => "system", "content" => "Be helpful." },
        { "role" => "system", "content" => "Be concise." },
        { "role" => "user",   "content" => "Hi" }
      ])
      expect(described_class.new(payload).build_request["system"]).to eq("Be helpful.\nBe concise.")
    end

    it "maps stop to stop_sequences" do
      payload = base_payload.merge("stop" => [ "\n", "END" ])
      expect(described_class.new(payload).build_request["stop_sequences"]).to eq([ "\n", "END" ])
    end
  end

  describe "#parse_response" do
    let(:anthropic_response) do
      {
        "id"          => "msg_01XFDUDYJgAACzvnptvVoYEL",
        "type"        => "message",
        "role"        => "assistant",
        "content"     => [ { "type" => "text", "text" => "Hello! How can I help?" } ],
        "model"       => "claude-3-5-sonnet-20241022",
        "stop_reason" => "end_turn",
        "usage"       => { "input_tokens" => 25, "output_tokens" => 11 }
      }
    end

    subject(:parsed) { adapter.parse_response(anthropic_response) }

    it "sets object to chat.completion" do
      expect(parsed["object"]).to eq("chat.completion")
    end

    it "preserves the response id" do
      expect(parsed["id"]).to eq("msg_01XFDUDYJgAACzvnptvVoYEL")
    end

    it "maps content text into choices[0].message.content" do
      expect(parsed.dig("choices", 0, "message", "content")).to eq("Hello! How can I help?")
    end

    it "sets role to assistant" do
      expect(parsed.dig("choices", 0, "message", "role")).to eq("assistant")
    end

    it "maps end_turn stop reason to stop" do
      expect(parsed.dig("choices", 0, "finish_reason")).to eq("stop")
    end

    it "maps max_tokens stop reason to length" do
      response = anthropic_response.merge("stop_reason" => "max_tokens")
      expect(adapter.parse_response(response).dig("choices", 0, "finish_reason")).to eq("length")
    end

    it "maps input_tokens to prompt_tokens" do
      expect(parsed.dig("usage", "prompt_tokens")).to eq(25)
    end

    it "maps output_tokens to completion_tokens" do
      expect(parsed.dig("usage", "completion_tokens")).to eq(11)
    end

    it "computes total_tokens" do
      expect(parsed.dig("usage", "total_tokens")).to eq(36)
    end

    it "concatenates multiple text content blocks" do
      response = anthropic_response.merge("content" => [
        { "type" => "text", "text" => "Hello! " },
        { "type" => "text", "text" => "How can I help?" }
      ])
      expect(adapter.parse_response(response).dig("choices", 0, "message", "content")).to eq("Hello! How can I help?")
    end
  end
end
