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

  around { |example| with_env("OPENAI_API_KEY" => "test-key") { example.run } }

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

  # ---------------------------------------------------------------------------
  # Backward compatibility — requests without prompt_protect should still work
  # ---------------------------------------------------------------------------
  context "backward compatibility (no prompt_protect key)" do
    let(:messages) { [ { "role" => "user", "content" => "What is the weather today?" } ] }

    before { stub_openai && post_completion(messages) }

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "does not include prompt_protect metadata in the response" do
      expect(JSON.parse(response.body)).not_to have_key("prompt_protect")
    end
  end

  # ---------------------------------------------------------------------------
  # Profile selection — lenient (sanitize instead of block, restore output)
  # ---------------------------------------------------------------------------
  context "with prompt_protect profile: lenient" do
    let(:messages) { [ { "role" => "user", "content" => "John Smith needs support with reading." } ] }

    def post_with_profile(profile, extra_opts = {})
      post "/v1/chat/completions",
        params: { model: model, messages: messages, prompt_protect: { profile: profile }.merge(extra_opts) }.to_json,
        headers: headers
    end

    context "when SSN is present (high risk) — lenient sanitizes instead of blocking" do
      let(:messages) { [ { "role" => "user", "content" => "Student SSN is 123-45-6789" } ] }

      before do
        stub_openai
        post_with_profile("lenient")
      end

      it "returns 200 (sanitizes rather than blocks)" do
        expect(response).to have_http_status(:ok)
      end

      it "masks the SSN before forwarding" do
        expect(a_request(:post, /openai\.com/).with { |req|
          !JSON.parse(req.body)["messages"].first["content"].include?("123-45-6789")
        }).to have_been_made
      end
    end

    context "with include_findings: true" do
      let(:messages) { [ { "role" => "user", "content" => "Email john@example.com for details." } ] }

      before do
        stub_openai
        post_with_profile("lenient", include_findings: true)
      end

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "includes prompt_protect metadata in the response" do
        body = JSON.parse(response.body)
        expect(body).to have_key("prompt_protect")
      end

      it "metadata includes the profile name" do
        pp_meta = JSON.parse(response.body)["prompt_protect"]
        expect(pp_meta["profile"]).to eq("lenient")
      end

      it "metadata includes the action taken" do
        pp_meta = JSON.parse(response.body)["prompt_protect"]
        expect(pp_meta["action"]).to eq("sanitize")
      end

      it "metadata includes findings_summary by type" do
        pp_meta = JSON.parse(response.body)["prompt_protect"]
        expect(pp_meta["findings_summary"]).to be_a(Hash)
        expect(pp_meta["findings_summary"]["email"]).to eq(1)
      end

      it "metadata does not include raw sensitive values" do
        pp_meta = JSON.parse(response.body)["prompt_protect"]
        expect(pp_meta.to_json).not_to include("john@example.com")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Inline policy_overrides (no named profile required)
  # ---------------------------------------------------------------------------
  context "with inline policy_overrides" do
    context "when high risk is overridden to sanitize" do
      let(:messages) { [ { "role" => "user", "content" => "SSN is 123-45-6789" } ] }

      before do
        stub_openai
        post "/v1/chat/completions",
          params: { model: model, messages: messages, prompt_protect: { policy_overrides: { high: "sanitize" } } }.to_json,
          headers: headers
      end

      it "returns 200 (sanitizes rather than blocks)" do
        expect(response).to have_http_status(:ok)
      end

      it "masks the SSN before forwarding" do
        expect(a_request(:post, /openai\.com/).with { |req|
          !JSON.parse(req.body)["messages"].first["content"].include?("123-45-6789")
        }).to have_been_made
      end
    end

    context "inline overrides take precedence over named profile" do
      let(:messages) { [ { "role" => "user", "content" => "SSN is 123-45-6789" } ] }

      before do
        stub_openai
        post "/v1/chat/completions",
          params: {
            model: model, messages: messages,
            prompt_protect: { profile: "lenient", policy_overrides: { high: "block" } }
          }.to_json,
          headers: headers
      end

      it "blocks (inline override wins over lenient profile)" do
        expect(response).to have_http_status(422)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Person-name detection and sanitization
  # ---------------------------------------------------------------------------
  context "person-name detection (default profile — person-only is low risk, allowed)" do
    let(:messages) { [ { "role" => "user", "content" => "John Smith needs support with reading." } ] }

    before { stub_openai && post_completion(messages) }

    it "detects the person name" do
      types = response.headers["X-Prompt-Protect-Detected-Types"].split(",")
      expect(types).to include("person")
    end

    it "sets risk level to low (person-only)" do
      expect(response.headers["X-Prompt-Protect-Risk-Level"]).to eq("low")
    end

    it "allows (does not mask) with default profile" do
      expect(response.headers["X-Prompt-Protect-Action"]).to eq("allow")
    end
  end

  context "person-name with lenient profile (person-only is still low→allow)" do
    let(:messages) { [ { "role" => "user", "content" => "John Smith needs support with reading." } ] }

    before do
      stub_openai
      post "/v1/chat/completions",
        params: { model: model, messages: messages, prompt_protect: { profile: "lenient" } }.to_json,
        headers: headers
    end

    it "detects the person name" do
      types = response.headers["X-Prompt-Protect-Detected-Types"].split(",")
      expect(types).to include("person")
    end

    it "allows (lenient only overrides high→sanitize; person-only is low→allow)" do
      expect(response.headers["X-Prompt-Protect-Action"]).to eq("allow")
    end
  end

  context "person-name with email (medium risk) — sanitization masks person placeholder" do
    let(:messages) { [ { "role" => "user", "content" => "John Smith sent john@example.com." } ] }

    before do
      stub_openai
      post_completion(messages)
    end

    it "sanitizes the message" do
      expect(response.headers["X-Prompt-Protect-Action"]).to eq("sanitize")
    end

    it "masks the email before forwarding" do
      expect(a_request(:post, /openai\.com/).with { |req|
        content = JSON.parse(req.body)["messages"].first["content"]
        !content.include?("john@example.com")
      }).to have_been_made
    end
  end

  # ---------------------------------------------------------------------------
  # Output restoration — restore_output: true/false
  # (uses email to trigger sanitize action reliably)
  # ---------------------------------------------------------------------------
  context "with restore_output: true/false" do
    # email triggers medium risk → sanitize
    let(:messages) { [ { "role" => "user", "content" => "Email john@example.com for details." } ] }

    def post_with_restore(restore_output)
      post "/v1/chat/completions",
        params: {
          model: model,
          messages: messages,
          prompt_protect: { profile: "default", restore_output: restore_output }
        }.to_json,
        headers: headers
    end

    before do
      stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-restore",
            object: "chat.completion",
            choices: [ { message: { role: "assistant", content: "I sent a message to [EMAIL_1]." } } ]
          }.to_json
        )
    end

    context "when restore_output is true" do
      before { post_with_restore(true) }

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "restores the original email in the response" do
        content = JSON.parse(response.body).dig("choices", 0, "message", "content")
        expect(content).to include("john@example.com")
        expect(content).not_to include("[EMAIL_1]")
      end
    end

    context "when restore_output is false" do
      before { post_with_restore(false) }

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "leaves placeholders in the response" do
        content = JSON.parse(response.body).dig("choices", 0, "message", "content")
        expect(content).to include("[EMAIL_1]")
        expect(content).not_to include("john@example.com")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Multiple entity restore correctness
  # (email triggers sanitize; person is low-risk/allowed — only email restored)
  # ---------------------------------------------------------------------------
  context "multiple-entity restore correctness" do
    let(:messages) do
      [
        { "role" => "user", "content" => "Contact jane@school.edu and notify bob@work.org." }
      ]
    end

    before do
      stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-multi",
            object: "chat.completion",
            choices: [ {
              message: {
                role: "assistant",
                content: "I emailed [EMAIL_1] and CC'd [EMAIL_2]."
              }
            } ]
          }.to_json
        )
      post "/v1/chat/completions",
        params: {
          model: model,
          messages: messages,
          prompt_protect: { restore_output: true }
        }.to_json,
        headers: headers
    end

    it "restores all email entities correctly" do
      content = JSON.parse(response.body).dig("choices", 0, "message", "content")
      expect(content).to include("jane@school.edu")
      expect(content).to include("bob@work.org")
      expect(content).not_to include("[EMAIL_1]")
      expect(content).not_to include("[EMAIL_2]")
    end
  end
end
