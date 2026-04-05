require "rails_helper"

RSpec.describe PromptProtect::TextNormalizer do
  subject(:normalizer) { described_class.new(text) }

  describe "#call" do
    context "Unicode NFKC normalization" do
      context "with fullwidth characters" do
        let(:text) { "ｊｏｈｎ＠ｅｘａｍｐｌｅ．ｃｏｍ" }

        it "collapses to ASCII" do
          expect(normalizer.call).to eq("john@example.com")
        end
      end

      context "with mathematical bold characters" do
        let(:text) { "𝐣𝐨𝐡𝐧@𝐞𝐱𝐚𝐦𝐩𝐥𝐞.𝐜𝐨𝐦" }

        it "collapses to ASCII" do
          expect(normalizer.call).to eq("john@example.com")
        end
      end

      context "with normal ASCII text" do
        let(:text) { "john@example.com" }

        it "leaves it unchanged" do
          expect(normalizer.call).to eq("john@example.com")
        end
      end
    end

    context "zero-width character stripping" do
      context "with zero-width spaces injected between characters" do
        let(:text) { "jo\u200Bhn@ex\u200Bample.com" }

        it "removes the invisible characters" do
          expect(normalizer.call).to eq("john@example.com")
        end
      end

      context "with zero-width non-joiner and joiner" do
        let(:text) { "john\u200C@\u200Dexample.com" }

        it "removes them" do
          expect(normalizer.call).to eq("john@example.com")
        end
      end

      context "with soft hyphen in a credit card number" do
        let(:text) { "1234\u00AD-5678\u00AD-9012\u00AD-3456" }

        it "strips soft hyphens so the pattern can match" do
          expect(normalizer.call).to eq("1234-5678-9012-3456")
        end
      end

      context "with byte-order mark" do
        let(:text) { "\uFEFFSome normal text" }

        it "strips the BOM" do
          expect(normalizer.call).to eq("Some normal text")
        end
      end
    end

    context "Base64 decode-and-expand" do
      context "with a Base64-encoded email" do
        # Base64 for "john@example.com"
        let(:text) { "Contact: #{Base64.strict_encode64('john@example.com').delete('=')}" }

        it "decodes and splices in the plaintext" do
          expect(normalizer.call).to include("john@example.com")
        end
      end

      context "with a Base64-encoded API key" do
        # Base64 for "sk-proj-abcdefghijklmnop"
        let(:text) { "Key: #{Base64.strict_encode64('sk-proj-abcdefghijklmnop')}" }

        it "decodes and splices in the plaintext" do
          expect(normalizer.call).to include("sk-proj-abcdefghijklmnop")
        end
      end

      context "with a short Base64-like string (below threshold)" do
        let(:text) { "Token: abc123XY" }

        it "leaves short strings unchanged" do
          expect(normalizer.call).to eq("Token: abc123XY")
        end
      end

      context "with a binary Base64 payload" do
        # Binary data — not printable text, should not be substituted
        let(:text) { "Data: #{Base64.strict_encode64("\x00\x01\x02\x03" * 10)}" }

        it "leaves binary blobs unchanged" do
          result = normalizer.call
          expect(result).not_to include("\x00")
        end
      end

      context "with plain text containing no encoding" do
        let(:text) { "What is the capital of France?" }

        it "returns the text unchanged" do
          expect(normalizer.call).to eq("What is the capital of France?")
        end
      end
    end

    context "end-to-end evasion scenarios" do
      context "fullwidth email evading EmailDetector" do
        let(:text) { "Send report to ｓａｒａｈ＠ａｃｍｅ．ｃｏｍ" }

        it "normalizes to a detectable email" do
          expect(normalizer.call).to include("sarah@acme.com")
        end
      end

      context "zero-width characters breaking an SSN pattern" do
        let(:text) { "SSN: 523\u200B-45\u200B-6789" }

        it "strips zero-width chars exposing the SSN" do
          expect(normalizer.call).to include("523-45-6789")
        end
      end
    end
  end
end
