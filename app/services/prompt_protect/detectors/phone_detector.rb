module PromptProtect
  module Detectors
    class PhoneDetector < BaseDetector
      # Matches common US/international formats:
      #   555-123-4567, (555) 123-4567, +1 555 123 4567, 5551234567
      PATTERN = /(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}\b/

      def call
        scan_findings(PATTERN, :phone)
      end
    end
  end
end
