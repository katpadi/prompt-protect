require "rails_helper"

RSpec.describe PromptProtect::Detectors::NerDetector do
  subject(:detector) { described_class.new(text) }

  let(:spacy_url) { "http://spacy:5001" }

  def stub_spacy(entities:)
    stub_request(:post, "#{spacy_url}/detect")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { entities: entities }.to_json
      )
  end

  describe "#call" do
    context "when spaCy returns PERSON entities" do
      let(:text) { "James Carter called Kat P. about the contract." }

      before do
        stub_spacy(entities: [
          { text: "James Carter", label: "PERSON", start: 0,  end: 12 },
          { text: "Kat P.",       label: "PERSON", start: 20, end: 26 }
        ])
      end

      it "returns a finding for each person" do
        expect(detector.call.size).to eq(2)
      end

      it "maps PERSON label to :person type" do
        types = detector.call.map { |f| f[:type] }
        expect(types).to all(eq(:person))
      end

      it "captures values and offsets correctly" do
        findings = detector.call
        expect(findings.first).to include(value: "James Carter", start: 0, end: 12)
        expect(findings.last).to  include(value: "Kat P.",       start: 20, end: 26)
      end
    end

    context "when spaCy returns ORG entities" do
      let(:text) { "She works at Acme Corp." }

      before do
        stub_spacy(entities: [
          { text: "Acme Corp", label: "ORG", start: 13, end: 22 }
        ])
      end

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "maps ORG label to :org type" do
        expect(detector.call.first[:type]).to eq(:org)
      end

      it "captures the value and offsets" do
        expect(detector.call.first).to include(value: "Acme Corp", start: 13, end: 22)
      end
    end

    context "when spaCy returns GPE (location) entities" do
      let(:text) { "The office is in Sydney." }

      before do
        stub_spacy(entities: [
          { text: "Sydney", label: "GPE", start: 17, end: 23 }
        ])
      end

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "maps GPE label to :location type" do
        expect(detector.call.first[:type]).to eq(:location)
      end
    end

    context "when spaCy returns LOC entities" do
      let(:text) { "They hiked through the Alps." }

      before do
        stub_spacy(entities: [
          { text: "Alps", label: "LOC", start: 22, end: 26 }
        ])
      end

      it "maps LOC label to :location type" do
        expect(detector.call.first[:type]).to eq(:location)
      end
    end

    context "when spaCy returns mixed entity types" do
      let(:text) { "Jane Smith at Acme Corp in London." }

      before do
        stub_spacy(entities: [
          { text: "Jane Smith", label: "PERSON", start: 0,  end: 10 },
          { text: "Acme Corp",  label: "ORG",    start: 14, end: 23 },
          { text: "London",     label: "GPE",    start: 27, end: 33 }
        ])
      end

      it "returns findings for all mapped types" do
        expect(detector.call.size).to eq(3)
      end

      it "maps each entity to the correct type" do
        types = detector.call.map { |f| f[:type] }
        expect(types).to contain_exactly(:person, :org, :location)
      end
    end

    context "when spaCy returns unmapped entity labels" do
      let(:text) { "Buy 10 shares of AAPL." }

      before do
        stub_spacy(entities: [
          { text: "10",   label: "CARDINAL", start: 4,  end: 6  },
          { text: "AAPL", label: "ORG",      start: 17, end: 21 }
        ])
      end

      it "filters out CARDINAL but maps ORG" do
        results = detector.call
        expect(results.size).to eq(1)
        expect(results.first[:type]).to eq(:org)
      end
    end

    context "when spaCy returns no entities" do
      let(:text) { "What is the weather today?" }

      before { stub_spacy(entities: []) }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end

    context "when spaCy service is unavailable" do
      let(:text) { "John Smith sent an email." }

      before do
        stub_request(:post, "#{spacy_url}/detect")
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "falls back to PersonDetector" do
        values = detector.call.map { |f| f[:value] }
        expect(values).to include("John Smith")
      end

      it "still returns :person type findings" do
        expect(detector.call.map { |f| f[:type] }).to all(eq(:person))
      end
    end

    context "when spaCy times out" do
      let(:text) { "Alice Johnson is here." }

      before do
        stub_request(:post, "#{spacy_url}/detect")
          .to_raise(Faraday::TimeoutError)
      end

      it "falls back to PersonDetector" do
        values = detector.call.map { |f| f[:value] }
        expect(values).to include("Alice Johnson")
      end
    end
  end
end
