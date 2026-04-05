module PromptProtect
  module Detectors
    class MedicalDetector < BaseDetector
      # Medical Record Number — keyword required (format varies too widely otherwise)
      # Matches: "MRN: 1234567", "medical record number: 0012345678"
      MRN_PATTERN = /\b(?:MRN|medical\s+record\s+(?:no\.?|number|#))\s*:?\s*\d{5,10}\b/i

      # ICD-10 diagnosis code — keyword required to avoid false positives on version numbers etc.
      # Matches: "diagnosis: J45.20", "ICD-10: A00.1", "dx: Z23"
      ICD10_PATTERN = /\b(?:diagnosis|ICD[-\s]?10|dx)\s*:?\s*[A-Z]\d{2}(?:\.\d{1,4})?\b/i

      # NHS number (UK) — keyword required
      # Matches: "NHS number: 943 476 5919", "NHS no: 9434765919"
      NHS_PATTERN = /\b(?:NHS\s+(?:no\.?|number)?)\s*:?\s*\d{3}\s?\d{3}\s?\d{4}\b/i

      # Medication with dosage — keyword required
      # Matches: "prescribed: metformin 500mg", "medication: lisinopril 10mg twice daily"
      MEDICATION_PATTERN = /\b(?:prescription|medication|prescribed|taking)\s*:?\s*[A-Za-z]{3,}(?:\s+[A-Za-z]{3,})?\s+\d+\s*(?:mg|mcg|ml|g|units?)\b/i

      # Health insurance member / policy ID — keyword required
      # Matches: "member ID: XYZ123456", "policy number: AB-123456789"
      INSURANCE_ID_PATTERN = /\b(?:member\s+id|insurance\s+(?:id|number|no\.?)|policy\s+(?:id|number|no\.?))\s*:?\s*[A-Z0-9\-]{6,20}\b/i

      PATTERNS = [
        [ MRN_PATTERN,         :medical ],
        [ ICD10_PATTERN,       :medical ],
        [ NHS_PATTERN,         :medical ],
        [ MEDICATION_PATTERN,  :medical ],
        [ INSURANCE_ID_PATTERN, :medical ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
