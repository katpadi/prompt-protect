module PromptProtect
  module Detectors
    class DobDetector < BaseDetector
      # All patterns require a keyword prefix to avoid flagging invoice/contract dates.

      # MM/DD/YYYY or DD/MM/YYYY or MM-DD-YYYY etc.
      # "DOB: 01/15/1990", "d.o.b 15-01-1990"
      NUMERIC_DOB_PATTERN = /\b(?:dob|d\.o\.b\.?|date\s+of\s+birth|birth\s*(?:date|day))\s*[:\-]?\s*
                              \d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b/ix

      # ISO 8601: YYYY-MM-DD
      # "date of birth: 1990-01-15"
      ISO_DOB_PATTERN = /\b(?:dob|d\.o\.b\.?|date\s+of\s+birth|birth\s*(?:date|day))\s*[:\-]?\s*
                          \d{4}-\d{2}-\d{2}\b/ix

      # Month name format: "born on January 15, 1990", "DOB: 15 March 1985"
      WRITTEN_DOB_PATTERN = /\b(?:dob|d\.o\.b\.?|date\s+of\s+birth|birth\s*(?:date|day)|born\s+on)\s*[:\-]?\s*
                              (?:\d{1,2}\s+)?
                              (?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|
                                 Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)
                              \s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b/ix

      PATTERNS = [
        [ NUMERIC_DOB_PATTERN,  :dob ],
        [ ISO_DOB_PATTERN,      :dob ],
        [ WRITTEN_DOB_PATTERN,  :dob ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
