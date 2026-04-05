require "rails_helper"

RSpec.describe "GET /health", type: :request do
  context "when NER sidecar is enabled and reachable" do
    around { |example| with_env("NER_ENABLED" => "true") { example.run } }

    before do
      stub_request(:get, "http://spacy:5001/health")
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { status: "ok", backend: "spacy", model: "en_core_web_sm" }.to_json
        )
    end

    it "returns ok with both checks passing" do
      get "/health"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body["checks"]["app"]["status"]).to eq("ok")
      expect(body["checks"]["ner"]["status"]).to eq("ok")
      expect(body["checks"]["ner"]["backend"]).to eq("spacy")
      expect(body["checks"]["ner"]["model"]).to eq("en_core_web_sm")
    end
  end

  context "when NER sidecar is unreachable" do
    around { |example| with_env("NER_ENABLED" => "true") { example.run } }

    before do
      stub_request(:get, "http://spacy:5001/health")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))
    end

    it "returns ok but ner check shows unreachable" do
      get "/health"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body["checks"]["app"]["status"]).to eq("ok")
      expect(body["checks"]["ner"]["status"]).to eq("unreachable")
      expect(body["checks"]["ner"]["error"]).to be_present
    end
  end

  context "when NER_ENABLED is false" do
    around { |example| with_env("NER_ENABLED" => "false") { example.run } }

    it "returns disabled for ner check without making a network call" do
      get "/health"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["checks"]["ner"]["status"]).to eq("disabled")
    end
  end
end
