module PromptProtect
  # Normalizes text before detection to defeat encoding-based evasion techniques.
  #
  # Three passes in order:
  #   1. Unicode NFKC — collapses fullwidth, halfwidth, mathematical, and
  #      decorative variants into ASCII equivalents (ｊｏｈｎ → john).
  #   2. Zero-width character stripping — removes invisible characters injected
  #      between characters to break regex matching.
  #   3. Base64 decode-and-rescan — extracts decodable Base64 blobs, decodes
  #      them, and splices the plaintext back in so detectors see the real value.
  #
  # The normalizer returns the cleaned text. Findings from the detection pipeline
  # reflect positions in the normalized text; the masking engine operates on it
  # as well, so masked output is coherent.
  class TextNormalizer
    # Invisible / zero-width Unicode characters that break regex matching
    ZERO_WIDTH_CHARS = [
      "\u200B", # zero-width space
      "\u200C", # zero-width non-joiner
      "\u200D", # zero-width joiner
      "\u00AD", # soft hyphen
      "\uFEFF", # byte-order mark / zero-width no-break space
      "\u2060"  # word joiner
    ].freeze

    ZERO_WIDTH_PATTERN = Regexp.union(ZERO_WIDTH_CHARS).freeze

    # Base64 blobs: at least 20 chars, standard or URL-safe alphabet, optional padding
    BASE64_PATTERN = /(?<![A-Za-z0-9+\/\-_])([A-Za-z0-9+\/\-_]{20,}={0,2})(?![A-Za-z0-9+\/\-_])/

    def initialize(text)
      @text = text.to_s
    end

    def call
      text = @text
      text = unicode_normalize(text)
      text = strip_zero_width(text)
      text = expand_base64(text)
      text
    end

    private

    def unicode_normalize(text)
      text.unicode_normalize(:nfkc)
    rescue Encoding::CompatibilityError, EncodingError
      text
    end

    def strip_zero_width(text)
      text.gsub(ZERO_WIDTH_PATTERN, "")
    end

    # Replace each decodable Base64 blob with its decoded plaintext so
    # downstream detectors see the original sensitive value.
    def expand_base64(text)
      text.gsub(BASE64_PATTERN) do |match|
        decoded = safe_decode_base64(match)
        # Only substitute when decoded content is readable ASCII text.
        # Skip if it looks like binary data, a hash, or a URL-safe token
        # that isn't hiding anything meaningful.
        (decoded && printable_text?(decoded) && decoded != match) ? decoded : match
      end
    end

    def safe_decode_base64(str)
      # Try standard then URL-safe alphabet
      [ str, str.tr("-_", "+/") ].each do |candidate|
        padded = candidate + "=" * ((4 - candidate.length % 4) % 4)
        decoded = Base64.strict_decode64(padded).encode("UTF-8", invalid: :replace, undef: :replace)
        return decoded
      rescue ArgumentError, Encoding::ConverterNotFoundError
        next
      end
      nil
    end

    # Accept decoded content only if it's mostly printable ASCII —
    # rejects binary payloads, image data, and cryptographic hashes.
    def printable_text?(str)
      return false if str.length < 4
      printable = str.count(" -~\t\n\r").to_f
      printable / str.length >= 0.80
    end
  end
end
