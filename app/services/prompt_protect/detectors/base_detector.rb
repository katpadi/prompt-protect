module PromptProtect
  module Detectors
    class BaseDetector
      def initialize(text)
        @text = text
      end

      def call
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      private

      def scan_findings(pattern, type)
        findings = []
        @text.scan(pattern) do
          md = Regexp.last_match
          findings << { type: type, value: md[0], start: md.begin(0), end: md.end(0) }
        end
        findings
      end
    end
  end
end
