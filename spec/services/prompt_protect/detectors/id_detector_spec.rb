require "rails_helper"

RSpec.describe PromptProtect::Detectors::IdDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with an SSN" do
      let(:text) { "SSN: 123-45-6789" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:id)
      end

      it "captures the correct value" do
        expect(detector.call.first[:value]).to eq("123-45-6789")
      end
    end

    context "with a valid credit card number (Luhn-valid)" do
      let(:text) { "Card: 4532015112830366" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "captures the correct value" do
        expect(detector.call.first[:value]).to eq("4532015112830366")
      end
    end

    context "with a credit card in grouped format (Luhn-valid)" do
      let(:text) { "Card: 4532-0151-1283-0366" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end
    end

    context "with a numeric sequence that is not Luhn-valid" do
      let(:text) { "Order ID: 1234-5678-9012-3456" }

      it "returns no findings" do
        expect(detector.call).to be_empty
      end
    end

    context "with a passport number" do
      let(:text) { "Passport no. AB1234567" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "captures the full passport reference" do
        expect(detector.call.first[:value]).to eq("Passport no. AB1234567")
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:id)
      end
    end

    context "with an IBAN" do
      let(:text) { "IBAN GB29NWBK60161331926819" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:id)
      end
    end

    context "with an Australian TFN" do
      let(:text) { "TFN 123 456 789" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:id)
      end
    end

    context "with an Australian Medicare number" do
      let(:text) { "Medicare card: 2123 45678 1" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:id)
      end
    end

    context "with both SSN and a valid credit card" do
      let(:text) { "SSN 123-45-6789 and card 4532015112830366" }

      it "returns two findings" do
        expect(detector.call.size).to eq(2)
      end
    end

    context "when text has no IDs" do
      let(:text) { "No sensitive data here." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
