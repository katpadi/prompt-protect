module PromptProtect
  module Detectors
    class SecretDetector < BaseDetector
      # Bearer token in Authorization header value
      # Matches: "Authorization: Bearer eyJhbGci...", "bearer TOKEN123"
      BEARER_TOKEN_PATTERN = /\bBearer\s+[A-Za-z0-9\-._~+\/]{20,}\b/i

      # Generic API key assignment — keyword required
      # Matches: api_key = "sk-abc123", "apikey": "ABCD1234efgh5678"
      API_KEY_PATTERN = /\bapi[_\-]?key\s*[=:]\s*["']?[A-Za-z0-9\-._]{16,}["']?/i

      # OpenAI-style secret keys: sk-... or sk-proj-...
      # Matches: sk-abc123XYZ (min 20 chars after sk-)
      OPENAI_KEY_PATTERN = /\bsk-[A-Za-z0-9\-]{20,}\b/

      # Generic secret/password assignment — keyword required
      # Matches: password = "hunter2", secret: "mysecretvalue"
      SECRET_ASSIGNMENT_PATTERN = /\b(?:password|passwd|secret|token)\s*[=:]\s*["']?[^\s"',;]{8,}["']?/i

      # AWS access key ID format
      # Matches: AKIAIOSFODNN7EXAMPLE (always starts with AKIA, 20 chars)
      AWS_KEY_PATTERN = /\bAKIA[0-9A-Z]{16}\b/

      PATTERNS = [
        [ BEARER_TOKEN_PATTERN,     :secret ],
        [ API_KEY_PATTERN,          :secret ],
        [ OPENAI_KEY_PATTERN,       :secret ],
        [ SECRET_ASSIGNMENT_PATTERN, :secret ],
        [ AWS_KEY_PATTERN,          :secret ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
