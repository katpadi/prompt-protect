require "rails_helper"

RSpec.describe PromptProtect::MaskingEngine do
  subject(:engine) { described_class.new(text, findings) }

  def finding(type, value, start_pos)
    { type: type, value: value, start: start_pos, end: start_pos + value.length }
  end

  describe "#call" do
    context "with no findings" do
      let(:text) { "Nothing sensitive here." }
      let(:findings) { [] }

      it "returns the original text unchanged" do
        expect(engine.call[:masked_text]).to eq(text)
      end

      it "returns an empty mapping" do
        expect(engine.call[:mapping]).to be_empty
      end
    end

    context "with a single email" do
      let(:text) { "Contact john@example.com for info" }
      let(:findings) { [ finding(:email, "john@example.com", 8) ] }

      it "replaces the email with a placeholder" do
        expect(engine.call[:masked_text]).to eq("Contact [EMAIL_1] for info")
      end

      it "maps the placeholder to the original value" do
        expect(engine.call[:mapping]).to eq({ "[EMAIL_1]" => "john@example.com" })
      end
    end

    context "with multiple findings of the same type" do
      let(:text) { "Email john@example.com or jane@test.org" }
      let(:findings) do
        [
          finding(:email, "john@example.com", 6),
          finding(:email, "jane@test.org", 26)
        ]
      end

      it "numbers placeholders sequentially" do
        masked = engine.call[:masked_text]
        expect(masked).to include("[EMAIL_1]", "[EMAIL_2]")
      end

      it "maps each placeholder independently" do
        mapping = engine.call[:mapping]
        expect(mapping["[EMAIL_1]"]).to eq("john@example.com")
        expect(mapping["[EMAIL_2]"]).to eq("jane@test.org")
      end
    end

    context "with mixed types" do
      let(:text) { "John Smith called 555-123-4567" }
      let(:findings) do
        [
          finding(:person, "John Smith", 0),
          finding(:phone, "555-123-4567", 18)
        ]
      end

      it "masks each type with its own placeholder prefix" do
        masked = engine.call[:masked_text]
        expect(masked).to include("[PERSON_1]", "[PHONE_1]")
      end

      it "does not include original sensitive values in masked text" do
        masked = engine.call[:masked_text]
        expect(masked).not_to include("John Smith", "555-123-4567")
      end
    end

    context "with overlapping findings" do
      let(:text) { "John Smith works here" }
      let(:findings) do
        [
          finding(:person, "John Smith", 0),
          finding(:person, "John", 0)   # overlaps with the first
        ]
      end

      it "keeps only the non-overlapping finding" do
        expect(engine.call[:masked_text]).to include("[PERSON_1]")
        expect(engine.call[:mapping].size).to eq(1)
      end
    end

    context "with findings in unsorted order" do
      let(:text) { "Call 555-123-4567 or email john@example.com" }
      let(:findings) do
        [
          finding(:email, "john@example.com", 27),
          finding(:phone, "555-123-4567", 5)
        ]
      end

      it "still masks correctly regardless of finding order" do
        masked = engine.call[:masked_text]
        expect(masked).to include("[PHONE_1]", "[EMAIL_1]")
        expect(masked).not_to include("555-123-4567", "john@example.com")
      end
    end
  end
end
