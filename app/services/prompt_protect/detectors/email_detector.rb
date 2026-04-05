module PromptProtect
  module Detectors
    class EmailDetector < BaseDetector
      PATTERN = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/

      def call
        scan_findings(PATTERN, :email)
      end
    end
  end
end
