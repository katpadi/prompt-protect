require "rails_helper"

RSpec.describe PromptProtect::Detectors::FinancialDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with a routing number" do
      let(:text) { "Routing number: 021000021" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:financial) }
      it { expect(detector.call.first[:value]).to match(/021000021/) }
    end

    context "with a bank account number" do
      let(:text) { "Account number: 000123456789" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:financial) }
    end

    context "with a UK sort code" do
      let(:text) { "Sort code: 20-00-00" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:financial) }
    end

    context "with a SWIFT code" do
      let(:text) { "SWIFT: NWBKGB2L" }

      it { expect(detector.call.size).to eq(1) }
      it { expect(detector.call.first[:type]).to eq(:financial) }
    end

    context "with routing and account together" do
      let(:text) { "Routing number: 021000021, account number: 123456789012" }

      it { expect(detector.call.size).to eq(2) }
      it { expect(detector.call.map { |f| f[:type] }.uniq).to eq([:financial]) }
    end

    context "when text has no financial data" do
      let(:text) { "Please process my refund of $25." }

      it { expect(detector.call).to be_empty }
    end

    context "does not fire on bare 9-digit numbers" do
      let(:text) { "Reference number 123456789 was issued." }

      it { expect(detector.call).to be_empty }
    end
  end
end
