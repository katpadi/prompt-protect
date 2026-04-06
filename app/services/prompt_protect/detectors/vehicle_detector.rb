module PromptProtect
  module Detectors
    class VehicleDetector < BaseDetector
      # VIN — keyword required; 17-char ISO format, no I/O/Q
      # Matches: "VIN: JTDBR32E720123456", "vehicle identification number: 1HGCM82633A004352"
      VIN_PATTERN = /\b(?:VIN|vehicle\s+identification\s+(?:no\.?|num(?:ber)?)?)\s*:?\s*[A-HJ-NPR-Z0-9]{17}\b/i

      # Registration plate — keyword required (plate formats vary too much by jurisdiction)
      # Matches: "Registration: ABC123", "Rego: ABC 123", "license plate: XY-1234"
      PLATE_PATTERN = /\b(?:(?:licen[cs]e|number)\s+plate|registration|rego|plate\s*(?:no\.?|num(?:ber)?|#)?)\s*:?\s*[A-Z0-9]{1,4}[\s\-]?[A-Z0-9]{1,4}\b/i

      PATTERNS = [
        [ VIN_PATTERN,   :vehicle ],
        [ PLATE_PATTERN, :vehicle ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
