module PromptProtect
  module Detectors
    class IdDetector < BaseDetector
      # US Social Security Number: 123-45-6789 or 123 45 6789
      SSN_PATTERN = /\b\d{3}[-\s]\d{2}[-\s]\d{4}\b/

      # Credit card: 1234-5678-9012-3456 or with spaces
      CREDIT_CARD_PATTERN = /\b(?:\d{4}[-\s]?){3}\d{4}\b/

      # Passport — keyword required to avoid false positives
      # Matches: "Passport AB1234567", "passport no. A12345678"
      PASSPORT_PATTERN = /\bpassport\s*(?:no\.?|num(?:ber)?|#|:)?\s*[A-Z]{1,2}\d{7,9}\b/i

      # IBAN — keyword required due to ambiguous alphanumeric format
      # Matches: "IBAN GB29NWBK60161331926819", "IBAN: DE89 3704 0044 0532 0130 00"
      IBAN_PATTERN = /\bIBAN\s*:?\s*[A-Z]{2}\d{2}[A-Z0-9](?:[A-Z0-9\s]{9,30})\b/i

      # Australian Tax File Number — keyword required (9-digit format is too generic alone)
      # Matches: "TFN 123 456 789", "tax file number: 123456789"
      AU_TFN_PATTERN = /\b(?:TFN|tax\s+file\s+(?:no\.?|number))\s*:?\s*\d{3}\s?\d{3}\s?\d{2,3}\b/i

      # Australian Medicare number — keyword required
      # Matches: "Medicare 2123 45678 1", "Medicare card: 212345678 1"
      AU_MEDICARE_PATTERN = /\bmedicare\s*(?:card|no\.?|number)?\s*:?\s*\d{4}\s?\d{5}\s?\d\b/i

      # Driver's license — keyword required (format varies too much by jurisdiction)
      # Matches: "DL: A1234567", "driver's license: D123-4567-8901", "driver license number: 12345678"
      DRIVERS_LICENSE_PATTERN = /\b(?:driver'?s?\s+licen[cs]e|driving\s+licen[cs]e|DL|DLN)\s*(?:no\.?|number|#)?\s*:?\s*[A-Z0-9][A-Z0-9\-\s]{4,14}\b/i

      PATTERNS = [
        [ SSN_PATTERN,              :id ],
        [ CREDIT_CARD_PATTERN,      :id ],
        [ PASSPORT_PATTERN,         :id ],
        [ IBAN_PATTERN,             :id ],
        [ AU_TFN_PATTERN,           :id ],
        [ AU_MEDICARE_PATTERN,      :id ],
        [ DRIVERS_LICENSE_PATTERN,  :id ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
