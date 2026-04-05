require "rails_helper"

RSpec.describe "POST /v1/chat/completions", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:model)   { "gpt-4o" }

  let(:openai_success_response) do
    {
      id: "chatcmpl-123",
      object: "chat.completion",
      choices: [ { message: { role: "assistant", content: "Hello!" } } ]
    }.to_json
  end

  def stub_openai(status: 200, body: openai_success_response)
    stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  def post_completion(messages)
    post "/v1/chat/completions",
      params: { model: model, messages: messages }.to_json,
      headers: headers
  end

  around do |example|
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
    example.run
    ENV["OPENAI_API_KEY"] = original
  end

  context "when content is low risk (no sensitive data)" do
    let(:messages) { [ { "role" => "user", "content" => "What is the weather today?" } ] }

    before { stub_openai && post_completion(messages) }

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "returns the OpenAI response body" do
      expect(JSON.parse(response.body)["id"]).to eq("chatcmpl-123")
    end

    it "sets risk level header to low" do
      expect(response.headers["X-Prompt-Protect-Risk-Level"]).to eq("low")
    end

    it "sets action header to allow" do
      expect(response.headers["X-Prompt-Protect-Action"]).to eq("allow")
    end

    it "sets detected types header to empty" do
      expect(response.headers["X-Prompt-Protect-Detected-Types"]).to eq("")
    end

    it "sets masked header to false" do
      expect(response.headers["X-Prompt-Protect-Masked"]).to eq("false")
    end
  end

  context "when content is medium risk (email detected)" do
    let(:messages) { [ { "role" => "user", "content" => "Email john@example.com" } ] }

    before { stub_openai && post_completion(messages) }

    it "sanitizes and forwards — returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "sends masked content to OpenAI, not the original email" do
      expect(a_request(:post, /openai\.com/).with { |req|
        body = JSON.parse(req.body)
        body["messages"].first["content"].include?("[EMAIL_1]") &&
          !body["messages"].first["content"].include?("john@example.com")
      }).to have_been_made
    end

    it "sets risk level header to medium" do
      expect(response.headers["X-Prompt-Protect-Risk-Level"]).to eq("medium")
    end

    it "sets action header to sanitize" do
      expect(response.headers["X-Prompt-Protect-Action"]).to eq("sanitize")
    end

    it "sets detected types header" do
      expect(response.headers["X-Prompt-Protect-Detected-Types"]).to eq("email")
    end

    it "sets masked header to true" do
      expect(response.headers["X-Prompt-Protect-Masked"]).to eq("true")
    end
  end

  context "when content is high risk (SSN detected)" do
    let(:messages) { [ { "role" => "user", "content" => "My SSN is 123-45-6789" } ] }

    before { post_completion(messages) }

    it "blocks the request with 422" do
      expect(response).to have_http_status(422)
    end

    it "returns a blocked error body" do
      body = JSON.parse(response.body)
      expect(body["error"]["type"]).to eq("blocked")
      expect(body["error"]["risk_level"]).to eq("high")
    end

    it "does not call OpenAI" do
      expect(a_request(:post, /openai\.com/)).not_to have_been_made
    end

    it "sets risk level header to high" do
      expect(response.headers["X-Prompt-Protect-Risk-Level"]).to eq("high")
    end

    it "sets action header to block" do
      expect(response.headers["X-Prompt-Protect-Action"]).to eq("block")
    end

    it "sets detected types header" do
      expect(response.headers["X-Prompt-Protect-Detected-Types"]).to eq("id")
    end

    it "sets masked header to false" do
      expect(response.headers["X-Prompt-Protect-Masked"]).to eq("false")
    end
  end

  context "when the LLM response contains PII (response scanning)" do
    let(:messages) { [ { "role" => "user", "content" => "Tell me about our customer." } ] }

    before do
      stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-456",
            object: "chat.completion",
            choices: [
              {
                message: {
                  role: "assistant",
                  content: "The customer is John Smith, reachable at john.smith@example.com and 555-123-4567."
                }
              }
            ]
          }.to_json
        )
      post_completion(messages)
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "masks PII in the response content" do
      content = JSON.parse(response.body).dig("choices", 0, "message", "content")
      expect(content).not_to include("john.smith@example.com")
      expect(content).not_to include("555-123-4567")
      expect(content).to include("[EMAIL_1]")
      expect(content).to include("[PHONE_1]")
    end

    it "sets response risk level header" do
      expect(response.headers["X-Prompt-Protect-Response-Risk-Level"]).to eq("high")
    end

    it "sets response detected types header" do
      types = response.headers["X-Prompt-Protect-Response-Detected-Types"].split(",")
      expect(types).to include("email", "phone")
    end

    it "sets response masked header to true" do
      expect(response.headers["X-Prompt-Protect-Response-Masked"]).to eq("true")
    end
  end

  context "when the LLM response contains no PII" do
    let(:messages) { [ { "role" => "user", "content" => "What is 2 + 2?" } ] }

    before do
      stub_openai
      post_completion(messages)
    end

    it "sets response masked header to false" do
      expect(response.headers["X-Prompt-Protect-Response-Masked"]).to eq("false")
    end

    it "sets response risk level to low" do
      expect(response.headers["X-Prompt-Protect-Response-Risk-Level"]).to eq("low")
    end

    it "leaves the response content unchanged" do
      content = JSON.parse(response.body).dig("choices", 0, "message", "content")
      expect(content).to eq("Hello!")
    end
  end

  context "when OpenAI returns an error" do
    let(:messages) { [ { "role" => "user", "content" => "Hello" } ] }

    it "returns 502 bad gateway" do
      stub_openai(status: 500, body: { error: { message: "Internal Server Error" } }.to_json)
      post_completion(messages)
      expect(response).to have_http_status(:bad_gateway)
    end
  end

  context "when OpenAI is unreachable" do
    let(:messages) { [ { "role" => "user", "content" => "Hello" } ] }

    it "returns 502 bad gateway" do
      stub_request(:post, /api\.openai\.com/).to_raise(Faraday::ConnectionFailed.new("connection refused"))
      post_completion(messages)
      expect(response).to have_http_status(:bad_gateway)
    end
  end

  context "with dry_run: true" do
    def post_dry_run(messages)
      post "/v1/chat/completions",
        params: { model: model, messages: messages, dry_run: true }.to_json,
        headers: headers
    end

    it "does not call OpenAI" do
      post_dry_run([ { "role" => "user", "content" => "Hello" } ])
      expect(a_request(:post, /openai\.com/)).not_to have_been_made
    end

    it "returns dry_run: true in the body" do
      post_dry_run([ { "role" => "user", "content" => "Hello" } ])
      expect(JSON.parse(response.body)["dry_run"]).to be true
    end

    it "returns risk_level and action" do
      post_dry_run([ { "role" => "user", "content" => "Hello" } ])
      body = JSON.parse(response.body)
      expect(body).to include("risk_level", "action")
    end

    context "when content has PII" do
      let(:messages) { [ { "role" => "user", "content" => "Email john@example.com" } ] }

      before { post_dry_run(messages) }

      it "returns masked_text with placeholder" do
        masked = JSON.parse(response.body)["messages"].first["masked_text"]
        expect(masked).to include("[EMAIL_1]")
      end

      it "returns findings with detected type" do
        findings = JSON.parse(response.body)["messages"].first["findings"]
        expect(findings.map { |f| f["type"] }).to include("email")
      end

      it "returns the mapping" do
        mapping = JSON.parse(response.body)["messages"].first["mapping"]
        expect(mapping["[EMAIL_1]"]).to eq("john@example.com")
      end
    end
  end
end
