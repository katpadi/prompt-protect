require "rails_helper"

RSpec.describe PromptProtect::PolicyEngine do
  subject(:engine) { described_class.new(risk_level) }

  describe "#call" do
    context "with default policy (no env overrides)" do
      it "returns :allow for :low risk" do
        expect(described_class.new(:low).call).to eq(:allow)
      end

      it "returns :sanitize for :medium risk" do
        expect(described_class.new(:medium).call).to eq(:sanitize)
      end

      it "returns :block for :high risk" do
        expect(described_class.new(:high).call).to eq(:block)
      end
    end

    context "with env overrides" do
      around do |example|
        original = {
          "PROMPT_PROTECT_POLICY_LOW" => ENV["PROMPT_PROTECT_POLICY_LOW"],
          "PROMPT_PROTECT_POLICY_MEDIUM" => ENV["PROMPT_PROTECT_POLICY_MEDIUM"],
          "PROMPT_PROTECT_POLICY_HIGH" => ENV["PROMPT_PROTECT_POLICY_HIGH"]
        }
        example.run
        original.each { |k, v| ENV[k] = v }
      end

      it "respects PROMPT_PROTECT_POLICY_LOW override" do
        ENV["PROMPT_PROTECT_POLICY_LOW"] = "sanitize"
        expect(described_class.new(:low).call).to eq(:sanitize)
      end

      it "respects PROMPT_PROTECT_POLICY_MEDIUM override" do
        ENV["PROMPT_PROTECT_POLICY_MEDIUM"] = "block"
        expect(described_class.new(:medium).call).to eq(:block)
      end

      it "respects PROMPT_PROTECT_POLICY_HIGH override" do
        ENV["PROMPT_PROTECT_POLICY_HIGH"] = "allow"
        expect(described_class.new(:high).call).to eq(:allow)
      end

      it "raises on invalid env value" do
        ENV["PROMPT_PROTECT_POLICY_LOW"] = "explode"
        expect { described_class.new(:low).call }.to raise_error(ArgumentError, /Invalid value/)
      end
    end

    context "with an unknown risk level" do
      let(:risk_level) { :extreme }

      it "raises ArgumentError" do
        expect { engine.call }.to raise_error(ArgumentError, /Unknown risk level/)
      end
    end
  end
end
