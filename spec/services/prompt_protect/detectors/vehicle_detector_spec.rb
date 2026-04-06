require "rails_helper"

RSpec.describe PromptProtect::Detectors::VehicleDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with a VIN" do
      let(:text) { "VIN: JTDBR32E720123456" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:vehicle)
      end

      it "captures the full match including keyword" do
        expect(detector.call.first[:value]).to include("JTDBR32E720123456")
      end
    end

    context "with a vehicle identification number (long form)" do
      let(:text) { "vehicle identification number: 1HGCM82633A004352" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:vehicle)
      end
    end

    context "with a registration plate (Registration prefix)" do
      let(:text) { "Registration: ABC123" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:vehicle)
      end
    end

    context "with a registration plate (Rego prefix)" do
      let(:text) { "Rego: ABC 123" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end
    end

    context "with a license plate prefix" do
      let(:text) { "license plate: XY-1234" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end
    end

    context "without a keyword (bare VIN-shaped string)" do
      let(:text) { "JTDBR32E720123456" }

      it "returns no findings" do
        expect(detector.call).to be_empty
      end
    end

    context "with a VIN containing invalid characters (I, O, Q)" do
      let(:text) { "VIN: JTDBR32O720123456" }

      it "returns no findings" do
        expect(detector.call).to be_empty
      end
    end

    context "when text has no vehicle data" do
      let(:text) { "Please review my code." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
