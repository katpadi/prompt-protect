require "rails_helper"

RSpec.describe PromptProtect::Detectors::EmailDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "when text contains a single email" do
      let(:text) { "Contact john@example.com for info" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:email)
      end

      it "captures the correct value" do
        expect(detector.call.first[:value]).to eq("john@example.com")
      end

      it "captures the correct start offset" do
        expect(detector.call.first[:start]).to eq(8)
      end
    end

    context "when text contains multiple emails" do
      let(:text) { "Email john@example.com or jane@test.org" }

      it "returns all findings" do
        expect(detector.call.size).to eq(2)
      end

      it "captures all values" do
        values = detector.call.map { |f| f[:value] }
        expect(values).to contain_exactly("john@example.com", "jane@test.org")
      end
    end

    context "when text has no email" do
      let(:text) { "No sensitive data here." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
