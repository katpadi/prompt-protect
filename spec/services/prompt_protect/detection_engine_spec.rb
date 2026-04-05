require "rails_helper"

RSpec.describe PromptProtect::DetectionEngine do
  subject(:engine) { described_class.new(text) }

  describe "#call" do
    context "with mixed sensitive data" do
      let(:text) { "John Smith's email is john@example.com and his phone is 555-123-4567" }

      before do
        stub_request(:post, /spacy:5001\/detect/)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { entities: [ { text: "John Smith", label: "PERSON", start: 0, end: 10 } ] }.to_json
          )
      end

      it "returns findings from multiple detectors" do
        types = engine.call.map { |f| f[:type] }
        expect(types).to include(:person, :email, :phone)
      end

      it "returns findings sorted by start position" do
        findings = engine.call
        starts = findings.map { |f| f[:start] }
        expect(starts).to eq(starts.sort)
      end
    end

    context "with clean text" do
      let(:text) { "The weather is nice today." }

      it "returns an empty array" do
        expect(engine.call).to be_empty
      end
    end

    context "with only an email" do
      let(:text) { "Send to hello@example.com" }

      it "returns one finding of type :email" do
        expect(engine.call.map { |f| f[:type] }).to eq([ :email ])
      end
    end

    it "each finding includes :type, :value, :start, and :end keys" do
      text = "Call john@example.com"
      finding = described_class.new(text).call.first
      expect(finding.keys).to include(:type, :value, :start, :end)
    end

    context "when SPACY_ENABLED is false" do
      around do |example|
        original = ENV["SPACY_ENABLED"]
        ENV["SPACY_ENABLED"] = "false"
        example.run
        ENV["SPACY_ENABLED"] = original
      end

      it "uses PersonDetector instead of NerDetector" do
        text = "John Smith sent this."
        findings = described_class.new(text).call
        expect(findings.map { |f| f[:type] }).to include(:person)
      end
    end
  end
end
