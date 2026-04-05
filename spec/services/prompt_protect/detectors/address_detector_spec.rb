require "rails_helper"

RSpec.describe PromptProtect::Detectors::AddressDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with a full street address" do
      let(:text) { "She lives at 123 Main Street in the city" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:address)
      end

      it "captures the street number and name" do
        expect(detector.call.first[:value]).to include("123 Main Street")
      end
    end

    context "with abbreviated street type" do
      let(:text) { "Office at 456 Oak Ave" }

      it "detects the address" do
        expect(detector.call).not_to be_empty
      end
    end

    context "with address and unit" do
      let(:text) { "Deliver to 789 Pine Blvd Apt 4B" }

      it "detects the address" do
        expect(detector.call).not_to be_empty
      end
    end

    context "when text has no address" do
      let(:text) { "No sensitive data here." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
