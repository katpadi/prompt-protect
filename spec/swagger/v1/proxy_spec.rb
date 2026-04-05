require "swagger_helper"

RSpec.describe "Prompt Protect API", type: :request do
  path "/v1/chat/completions" do
    post "Send a prompt through Prompt Protect" do
      tags        "Proxy"
      consumes    "application/json"
      produces    "application/json"
      description <<~DESC
        Drop-in replacement for the OpenAI `/v1/chat/completions` endpoint.

        Prompt Protect inspects each message, computes a risk level, and applies policy before forwarding.

        ### Use cases

        **Allow** (risk: `low`) — prompt contains no sensitive data.
        Forwarded to OpenAI unchanged. Example: `"What is the capital of France?"`

        **Sanitize** (risk: `medium`) — prompt contains PII (email, phone, or address).
        Sensitive values are replaced with placeholders before forwarding. The original values never reach OpenAI.
        Example: `"Email john@example.com"` → forwarded as `"Email [EMAIL_1]"`

        **Block** (risk: `high`) — prompt contains an ID number (SSN, credit card) or multiple sensitive types.
        Request is rejected immediately — OpenAI is never called.
        Example: `"My SSN is 123-45-6789"`

        ### Risk rules

        | Risk | Triggers |
        |---|---|
        | `high` | Any ID number, or 2+ sensitive types detected |
        | `medium` | One sensitive type (email, phone, or address) |
        | `low` | Person name only, or no findings |

        ### Transparency headers

        Every response includes:

        | Header | Description |
        |---|---|
        | `X-Prompt-Protect-Risk-Level` | `low` / `medium` / `high` |
        | `X-Prompt-Protect-Action` | `allow` / `sanitize` / `block` |
        | `X-Prompt-Protect-Detected-Types` | Comma-separated PII types found (e.g. `email,person`) |
        | `X-Prompt-Protect-Masked` | `true` if content was masked before forwarding |
      DESC

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: [ "model", "messages" ],
        properties: {
          model: {
            type: :string,
            example: "gpt-4o",
            description: "The LLM model to use"
          },
          messages: {
            type: :array,
            description: "Conversation messages (OpenAI format)",
            items: {
              type: :object,
              required: [ "role", "content" ],
              properties: {
                role:    { type: :string, enum: [ "system", "user", "assistant" ] },
                content: { type: :string }
              }
            }
          }
        },
        example: {
          model: "gpt-4o",
          messages: [ { role: "user", content: "What is the capital of France?" } ]
        }
      }

      # ── 200: Allowed ──────────────────────────────────────────────────────
      response "200", "Allowed — clean content forwarded to OpenAI as-is (risk: low, action: allow)" do
        header "X-Prompt-Protect-Risk-Level",     schema: { type: :string, example: "low" },   description: "Computed risk level"
        header "X-Prompt-Protect-Action",         schema: { type: :string, example: "allow" },  description: "Policy action taken"
        header "X-Prompt-Protect-Detected-Types", schema: { type: :string, example: "" },        description: "Empty — no PII detected"
        header "X-Prompt-Protect-Masked",         schema: { type: :string, example: "false" },   description: "Content was not masked"

        schema type: :object, properties: {
          id:      { type: :string, example: "chatcmpl-abc123" },
          object:  { type: :string, example: "chat.completion" },
          choices: {
            type: :array,
            items: {
              type: :object,
              properties: {
                message: {
                  type: :object,
                  properties: {
                    role:    { type: :string, example: "assistant" },
                    content: { type: :string, example: "The capital of France is Paris." }
                  }
                }
              }
            }
          }
        }

        let(:body) do
          {
            model: "gpt-4o",
            messages: [ { role: "user", content: "What is the capital of France?" } ]
          }
        end

        before do
          stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
            .to_return(
              status: 200,
              headers: { "Content-Type" => "application/json" },
              body: {
                id: "chatcmpl-abc123",
                object: "chat.completion",
                choices: [ { message: { role: "assistant", content: "The capital of France is Paris." } } ]
              }.to_json
            )
          ENV["OPENAI_API_KEY"] = "test-key"
        end

        after { ENV.delete("OPENAI_API_KEY") }

        run_test!
      end

      # ── 422: Blocked ──────────────────────────────────────────────────────
      response "422", "Blocked — high-risk content detected, OpenAI never called (risk: high, action: block)" do
        header "X-Prompt-Protect-Risk-Level",     schema: { type: :string, example: "high" },   description: "Computed risk level"
        header "X-Prompt-Protect-Action",         schema: { type: :string, example: "block" },   description: "Policy action taken"
        header "X-Prompt-Protect-Detected-Types", schema: { type: :string, example: "id" },      description: "Detected PII types"
        header "X-Prompt-Protect-Masked",         schema: { type: :string, example: "false" },   description: "Always false — request was not forwarded"

        schema type: :object, properties: {
          error: {
            type: :object,
            properties: {
              type:       { type: :string, example: "blocked" },
              message:    { type: :string, example: "Request blocked: high risk content detected" },
              risk_level: { type: :string, example: "high" }
            }
          }
        }

        let(:body) do
          {
            model: "gpt-4o",
            messages: [ { role: "user", content: "My SSN is 123-45-6789, help me fill out this form." } ]
          }
        end

        run_test!
      end

      # ── 502: Upstream error ───────────────────────────────────────────────
      response "502", "Upstream error — OpenAI returned an error or could not be reached" do
        schema type: :object, properties: {
          error: {
            type: :object,
            properties: {
              type:    { type: :string, example: "upstream_error" },
              message: { type: :string, example: "Upstream returned 500" }
            }
          }
        }

        let(:body) do
          {
            model: "gpt-4o",
            messages: [ { role: "user", content: "Hello!" } ]
          }
        end

        before do
          stub_request(:post, /api\.openai\.com\/v1\/chat\/completions/)
            .to_return(
              status: 500,
              headers: { "Content-Type" => "application/json" },
              body: { error: { message: "Internal Server Error" } }.to_json
            )
          ENV["OPENAI_API_KEY"] = "test-key"
        end

        after { ENV.delete("OPENAI_API_KEY") }

        run_test!
      end
    end
  end

  path "/health" do
    get "Health check" do
      tags        "System"
      produces    "application/json"
      description "Returns 200 if the service is up. Safe to use as a liveness probe."

      response "200", "Service is healthy" do
        schema type: :object, properties: {
          status:  { type: :string, example: "ok" },
          service: { type: :string, example: "prompt-protect" }
        }

        run_test!
      end
    end
  end
end
