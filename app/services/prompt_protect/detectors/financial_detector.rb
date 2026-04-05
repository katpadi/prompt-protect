module PromptProtect
  module Detectors
    class FinancialDetector < BaseDetector
      # US ABA routing number — keyword required (9 digits is too generic alone)
      # Matches: "routing number: 021000021", "ABA: 111000025"
      ROUTING_NUMBER_PATTERN = /\b(?:routing|ABA)\s*(?:no\.?|number|#)?\s*:?\s*\d{9}\b/i

      # Bank account number — keyword required
      # Matches: "account number: 12345678901", "acct no: 000123456"
      ACCOUNT_NUMBER_PATTERN = /\b(?:account|acct)\.?\s*(?:no\.?|number|#)\s*:?\s*\d{6,17}\b/i

      # UK sort code — keyword required (XX-XX-XX or XX XX XX)
      # Matches: "sort code: 20-00-00", "sort code: 200000"
      SORT_CODE_PATTERN = /\b(?:sort\s*code)\s*:?\s*\d{2}[-\s]?\d{2}[-\s]?\d{2}\b/i

      # SWIFT / BIC code — keyword required
      # Matches: "SWIFT: NWBKGB2L", "BIC code: DEUTDEDB"
      SWIFT_PATTERN = /\b(?:SWIFT|BIC)\s*(?:code)?\s*:?\s*[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\b/i

      PATTERNS = [
        [ ROUTING_NUMBER_PATTERN, :financial ],
        [ ACCOUNT_NUMBER_PATTERN, :financial ],
        [ SORT_CODE_PATTERN,      :financial ],
        [ SWIFT_PATTERN,          :financial ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
