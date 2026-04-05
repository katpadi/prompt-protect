require "rails_helper"

RSpec.describe PromptProtect::Detectors::DobDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with a numeric DOB (MM/DD/YYYY)" do
      let(:text) { "DOB: 01/15/1990" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:dob)
      end

      it "captures the full DOB reference" do
        expect(detector.call.first[:value]).to eq("DOB: 01/15/1990")
      end
    end

    context "with d.o.b. format" do
      let(:text) { "d.o.b. 15-03-1985" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:dob)
      end
    end

    context "with full date of birth phrase" do
      let(:text) { "date of birth: 1990-01-15" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:dob)
      end
    end

    context "with written month format" do
      let(:text) { "DOB: January 15, 1990" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:dob)
      end
    end

    context "with 'born on' prefix" do
      let(:text) { "born on March 5th, 1988" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:dob)
      end
    end

    context "with birthdate keyword" do
      let(:text) { "birthdate: 12/25/1992" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end
    end

    context "with a bare date (no keyword)" do
      let(:text) { "The contract was signed on 01/15/1990." }

      it "returns no findings" do
        expect(detector.call).to be_empty
      end
    end

    context "with an invoice date (no keyword)" do
      let(:text) { "Invoice date: 2024-03-01" }

      it "returns no findings" do
        expect(detector.call).to be_empty
      end
    end

    context "when text has no DOB" do
      let(:text) { "No date information here." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
