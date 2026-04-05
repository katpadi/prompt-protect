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

    context "when text has no secrets" do
      let(:text) { "Please help me with my code." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
