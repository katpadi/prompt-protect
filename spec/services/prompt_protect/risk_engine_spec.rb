require "rails_helper"

RSpec.describe PromptProtect::RiskEngine do
  subject(:engine) { described_class.new(findings) }

  def finding(type)
    { type: type, value: "x", start: 0, end: 1 }
  end

  def call_level(findings)
    described_class.new(findings).call.level
  end

  describe "#call" do
    it "returns a Result with level and explanation" do
      result = described_class.new([]).call
      expect(result).to respond_to(:level, :explanation)
    end

    context "with no findings" do
      let(:findings) { [] }

      it "returns :low" do
        expect(engine.call.level).to eq(:low)
      end

      it "sets rule to clean" do
        expect(engine.call.explanation[:rule]).to eq("clean")
      end
    end

    context "with person only" do
      let(:findings) { [ finding(:person) ] }

      it "returns :low" do
        expect(engine.call.level).to eq(:low)
      end

      it "sets rule to person_only" do
        expect(engine.call.explanation[:rule]).to eq("person_only")
      end
    end

    context "with org only" do
      let(:findings) { [ finding(:org) ] }

      it "returns :low" do
        expect(engine.call.level).to eq(:low)
      end
    end

    context "with location only" do
      let(:findings) { [ finding(:location) ] }

      it "returns :low" do
        expect(engine.call.level).to eq(:low)
      end
    end

    context "with person and org (affiliation)" do
      let(:findings) { [ finding(:person), finding(:org) ] }

      it "returns :medium" do
        expect(engine.call.level).to eq(:medium)
      end

      it "sets rule to person_with_context" do
        expect(engine.call.explanation[:rule]).to eq("person_with_context")
      end
    end

    context "with person and location (whereabouts)" do
      let(:findings) { [ finding(:person), finding(:location) ] }

      it "returns :medium" do
        expect(engine.call.level).to eq(:medium)
      end
    end

    context "with person, org, and location" do
      let(:findings) { [ finding(:person), finding(:org), finding(:location) ] }

      it "returns :high (mosaic profile — name + employer + location)" do
        expect(engine.call.level).to eq(:high)
      end

      it "sets rule to mosaic_profile" do
        expect(engine.call.explanation[:rule]).to eq("mosaic_profile")
      end
    end

    context "with a single sensitive type" do
      it "returns :medium for email" do
        expect(call_level([ finding(:email) ])).to eq(:medium)
      end

      it "returns :medium for phone" do
        expect(call_level([ finding(:phone) ])).to eq(:medium)
      end

      it "returns :medium for address" do
        expect(call_level([ finding(:address) ])).to eq(:medium)
      end

      it "returns :medium for ip" do
        expect(call_level([ finding(:ip) ])).to eq(:medium)
      end

      it "returns :medium for dob alone" do
        expect(call_level([ finding(:dob) ])).to eq(:medium)
      end
    end

    context "with a critical type (secret)" do
      let(:findings) { [ finding(:secret) ] }

      it "returns :high" do
        expect(engine.call.level).to eq(:high)
      end

      it "sets rule to critical_type" do
        expect(engine.call.explanation[:rule]).to eq("critical_type")
      end
    end

    context "with DOB and person (identity reconstruction)" do
      let(:findings) { [ finding(:dob), finding(:person) ] }

      it "returns :high" do
        expect(engine.call.level).to eq(:high)
      end

      it "sets rule to identity_reconstruction" do
        expect(engine.call.explanation[:rule]).to eq("identity_reconstruction")
      end
    end

    context "with DOB alone (no person)" do
      let(:findings) { [ finding(:dob) ] }

      it "returns :medium" do
        expect(engine.call.level).to eq(:medium)
      end
    end

    context "with a sensitive type and person" do
      let(:findings) { [ finding(:email), finding(:person) ] }

      it "returns :medium" do
        expect(engine.call.level).to eq(:medium)
      end
    end

    context "with two or more sensitive types" do
      let(:findings) { [ finding(:email), finding(:phone) ] }

      it "returns :medium" do
        expect(engine.call.level).to eq(:medium)
      end

      it "sets rule to multiple_sensitive" do
        expect(engine.call.explanation[:rule]).to eq("multiple_sensitive")
      end
    end

    context "with a critical type (id)" do
      let(:findings) { [ finding(:id) ] }

      it "returns :high" do
        expect(engine.call.level).to eq(:high)
      end
    end

    context "with id and other types" do
      let(:findings) { [ finding(:id), finding(:person) ] }

      it "still returns :high" do
        expect(engine.call.level).to eq(:high)
      end
    end

    context "with all types present" do
      let(:findings) { [ :email, :phone, :address, :id, :person ].map { |t| finding(t) } }

      it "returns :high" do
        expect(engine.call.level).to eq(:high)
      end
    end

    context "explanation content" do
      let(:findings) { [ { type: :id, value: "523-45-6789", start: 0, end: 11 } ] }

      it "includes detected_values" do
        expect(engine.call.explanation[:detected_values]).to include("523-45-6789")
      end

      it "includes triggered_by types as strings" do
        expect(engine.call.explanation[:triggered_by]).to include("id")
      end

      it "includes a human-readable reason" do
        expect(engine.call.explanation[:reason]).to be_a(String)
        expect(engine.call.explanation[:reason]).not_to be_empty
      end
    end

    context "mosaic profile scoring" do
      context "with exactly 2 mosaic types (below threshold)" do
        let(:findings) { [ finding(:person), finding(:org) ] }

        it "returns :medium (person_with_context, not mosaic)" do
          expect(engine.call.level).to eq(:medium)
        end
      end

      context "with 3 mosaic types (name + employer + location)" do
        let(:findings) { [ finding(:person), finding(:org), finding(:location) ] }

        it "returns :high (mosaic profile)" do
          expect(engine.call.level).to eq(:high)
        end
      end

      context "with 3 mosaic types (name + email + location)" do
        let(:findings) { [ finding(:person), finding(:email), finding(:location) ] }

        it "returns :high (mosaic profile)" do
          expect(engine.call.level).to eq(:high)
        end
      end

      context "with 4 mosaic types (name + employer + location + dob)" do
        let(:findings) { [ finding(:person), finding(:org), finding(:location), finding(:dob) ] }

        it "returns :high (mosaic profile)" do
          expect(engine.call.level).to eq(:high)
        end
      end

      context "with 3 non-mosaic types (address, ip, phone)" do
        let(:findings) { [ finding(:address), finding(:ip), finding(:phone) ] }

        it "returns :medium via multiple_sensitive, not mosaic" do
          expect(engine.call.level).to eq(:medium)
        end
      end
    end
  end
end
