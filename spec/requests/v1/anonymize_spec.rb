require "rails_helper"

RSpec.describe "POST /v1/anonymize", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }

  def post_anonymize(body)
    post "/v1/anonymize", params: body.to_json, headers: headers
  end

  context "with a person name" do
    before { post_anonymize(text: "John Smith needs support with reading.") }

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "returns sanitized_text with placeholder" do
      body = JSON.parse(response.body)
      expect(body["sanitized_text"]).to include("[PERSON_1]")
      expect(body["sanitized_text"]).not_to include("John Smith")
    end

    it "returns findings" do
      findings = JSON.parse(response.body)["findings"]
      expect(findings).to be_an(Array)
      expect(findings.map { |f| f["type"] }).to include("person")
    end
  end

  context "with an email address" do
    before { post_anonymize(text: "Contact jane@school.edu for details.") }

    it "replaces the email with a placeholder" do
      body = JSON.parse(response.body)
      expect(body["sanitized_text"]).to include("[EMAIL_1]")
      expect(body["sanitized_text"]).not_to include("jane@school.edu")
    end
  end

  context "with no PII" do
    before { post_anonymize(text: "The weather is nice today.") }

    it "returns the original text unchanged" do
      body = JSON.parse(response.body)
      expect(body["sanitized_text"]).to eq("The weather is nice today.")
      expect(body["findings"]).to be_empty
    end
  end

  context "with multiple entities" do
    before { post_anonymize(text: "John Smith emailed jane@school.edu about the assignment.") }

    it "replaces all detected entities" do
      body = JSON.parse(response.body)
      expect(body["sanitized_text"]).not_to include("John Smith")
      expect(body["sanitized_text"]).not_to include("jane@school.edu")
    end

    it "returns findings for each entity" do
      findings = JSON.parse(response.body)["findings"]
      types = findings.map { |f| f["type"] }
      expect(types).to include("person", "email")
    end
  end
end
