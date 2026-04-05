module PromptProtect
  module Detectors
    class IpDetector < BaseDetector
      # IPv4 address
      # Matches: 192.168.1.1, 10.0.0.1 — validates octet range (0-255)
      IPV4_PATTERN = /\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b/

      # IPv6 address — full and compressed forms
      # Matches: 2001:0db8:85a3:0000:0000:8a2e:0370:7334, ::1, fe80::1
      IPV6_PATTERN = /(?<![:\w])(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}(?![:\w])|
                      (?<![:\w])(?:[0-9a-fA-F]{1,4}:){1,7}:(?![:\w])|
                      (?<![:\w]):(?::[0-9a-fA-F]{1,4}){1,7}(?![:\w])|
                      (?<![:\w])::1(?![:\w])/x

      PATTERNS = [
        [ IPV4_PATTERN, :ip ],
        [ IPV6_PATTERN, :ip ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
