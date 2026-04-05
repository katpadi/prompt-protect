require "rails_helper"

RSpec.describe PromptProtect::Detectors::MedicalDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with a medical record number" do
      let(:text) { "MRN: 1234567" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:medical) }
      it { expect(detector.call.first[:value]).to match(/1234567/) }
    end

    context "with an ICD-10 code" do
      let(:text) { "Diagnosis: J45.20" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:medical) }
    end

    context "with an NHS number" do
      let(:text) { "NHS number: 943 476 5919" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:medical) }
    end

    context "with a medication and dosage" do
      let(:text) { "Prescribed: metformin 500mg" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:medical) }
    end

    context "with a health insurance member ID" do
      let(:text) { "Member ID: XYZ123456789" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:medical) }
    end

    context "with multiple medical entities" do
      let(:text) { "MRN: 9876543. Diagnosis: E11.9. Prescribed: insulin 10 units" }

      it { expect(detector.call.size).to eq(3) }
    end

    context "when text has no medical data" do
      let(:text) { "The patient was seen last Tuesday." }

      it { expect(detector.call).to be_empty }
    end

    context "does not fire on bare diagnosis words without codes" do
      let(:text) { "The diagnosis is still unclear." }

      it { expect(detector.call).to be_empty }
    end
  end
end
