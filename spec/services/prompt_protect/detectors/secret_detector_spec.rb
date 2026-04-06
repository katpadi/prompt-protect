require "rails_helper"

RSpec.describe PromptProtect::Detectors::SecretDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with a Bearer token" do
      let(:text) { "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end

      it "captures the token" do
        expect(detector.call.first[:value]).to include("Bearer")
      end
    end

    context "with an api_key assignment" do
      let(:text) { 'api_key = "ABCD1234efgh5678XYZ9"' }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end
    end

    context "with an OpenAI-style secret key" do
      let(:text) { "My key is sk-proj-abcdefghijklmnopqrstuvwxyz123456" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end
    end

    context "with a password assignment" do
      let(:text) { "password = hunter2secret" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end
    end

    context "with an AWS access key" do
      let(:text) { "AWS key: AKIAIOSFODNN7EXAMPLE" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end

      it "captures the key value" do
        expect(detector.call.first[:value]).to eq("AKIAIOSFODNN7EXAMPLE")
      end
    end

    context "with a GitHub personal access token" do
      let(:text) { "my github token is ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ123456" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end

      it "captures the token" do
        expect(detector.call.first[:value]).to include("ghp_")
      end
    end

    context "with a GitHub fine-grained token" do
      let(:text) { "github_pat_11ABCDE0abcdefghijklmnopqrstuvwxyz1234567890" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end
    end

    context "with a GitLab access token" do
      let(:text) { "GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end
    end

    context "with a Slack bot token" do
      let(:text) { "slack_token: xoxb-123456789012-1234567890123-abcdefghijklmnopqrstuvwx" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end
    end

    context "with a Slack webhook URL" do
      let(:text) { "webhook: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end
    end

    context "with an Azure storage AccountKey" do
      let(:text) { "DefaultEndpointsProtocol=https;AccountName=myaccount;AccountKey=dGVzdGtleXZhbHVlZm9yYXp1cmVzdG9yYWdlYWNjb3VudA==" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:secret)
      end
    end

    context "when text has no secrets" do
      let(:text) { "Please help me with my code." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
