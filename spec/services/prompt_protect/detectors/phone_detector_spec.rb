require "rails_helper"

RSpec.describe PromptProtect::Detectors::PhoneDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with dashes format" do
      let(:text) { "Call me at 555-123-4567 anytime" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:phone)
      end

      it "captures the correct value" do
        expect(detector.call.first[:value]).to eq("555-123-4567")
      end
    end

    context "with parentheses format" do
      let(:text) { "Reach us at (555) 123-4567" }

      it "detects the phone number" do
        expect(detector.call).not_to be_empty
      end
    end

    context "with international format" do
      let(:text) { "International: +1 555-123-4567" }

      it "detects the phone number" do
        expect(detector.call).not_to be_empty
      end
    end

    context "when text has no phone number" do
      let(:text) { "No sensitive data here." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
