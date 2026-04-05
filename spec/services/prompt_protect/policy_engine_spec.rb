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
      it "respects PROMPT_PROTECT_POLICY_LOW override" do
        with_env("PROMPT_PROTECT_POLICY_LOW" => "sanitize") do
          expect(described_class.new(:low).call).to eq(:sanitize)
        end
      end

      it "respects PROMPT_PROTECT_POLICY_MEDIUM override" do
        with_env("PROMPT_PROTECT_POLICY_MEDIUM" => "block") do
          expect(described_class.new(:medium).call).to eq(:block)
        end
      end

      it "respects PROMPT_PROTECT_POLICY_HIGH override" do
        with_env("PROMPT_PROTECT_POLICY_HIGH" => "allow") do
          expect(described_class.new(:high).call).to eq(:allow)
        end
      end

      it "raises on invalid env value" do
        with_env("PROMPT_PROTECT_POLICY_LOW" => "explode") do
          expect { described_class.new(:low).call }.to raise_error(ArgumentError, /Invalid value/)
        end
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
