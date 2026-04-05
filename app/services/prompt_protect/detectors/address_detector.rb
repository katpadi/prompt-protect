module PromptProtect
  module Detectors
    class AddressDetector < BaseDetector
      # Matches patterns like: 123 Main Street, 456 Oak Ave, 789 Pine Blvd Apt 2
      PATTERN = /\d+\s+[A-Za-z][A-Za-z0-9\s]+
                 (?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|
                    Drive|Dr|Lane|Ln|Court|Ct|Way|Place|Pl)\.?
                 (?:\s+(?:Apt|Suite|Unit|\#)\s*\w+)?/ix

      def call
        scan_findings(PATTERN, :address)
      end
    end
  end
end
