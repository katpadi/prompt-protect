require "rails_helper"

RSpec.describe PromptProtect::Detectors::PersonDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with an honorific and full name" do
      let(:text) { "Dr. Jane Smith is the lead" }

      it "returns a finding" do
        expect(detector.call).not_to be_empty
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:person)
      end

      it "captures the full name including honorific" do
        expect(detector.call.first[:value]).to eq("Dr. Jane Smith")
      end
    end

    context "with a plain full name" do
      let(:text) { "Contact John Smith for details" }

      it "returns a finding" do
        expect(detector.call).not_to be_empty
      end

      it "includes the name in findings" do
        values = detector.call.map { |f| f[:value] }
        expect(values).to include("John Smith")
      end
    end

    context "with multiple names" do
      let(:text) { "John Smith and Alice Johnson attended" }

      it "returns a finding for each name" do
        expect(detector.call.size).to eq(2)
      end
    end

    context "with honorific name already covered by full-name pattern" do
      let(:text) { "Mr. John Smith called" }

      it "does not return duplicate findings for the same span" do
        values = detector.call.map { |f| f[:value] }
        expect(values.uniq.size).to eq(values.size)
      end
    end

    context "with a name followed by a single initial" do
      let(:text) { "Kat P. (Kat.Pad@katpadi.ph) is an astronaut." }

      it "detects the name" do
        values = detector.call.map { |f| f[:value] }
        expect(values).to include("Kat P.")
      end
    end

    context "with an initial followed by a surname" do
      let(:text) { "The report was filed by J. Smith yesterday." }

      it "detects the name" do
        values = detector.call.map { |f| f[:value] }
        expect(values).to include("J. Smith")
      end
    end

    context "with capitalized legal defined terms" do
      let(:text) { "This Vehicle Loan Agreement is between the Lender and Borrower." }

      it "does not flag defined terms as person names" do
        expect(detector.call).to be_empty
      end
    end

    context "when text has no names" do
      let(:text) { "the weather is nice today" }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end
  end
end
