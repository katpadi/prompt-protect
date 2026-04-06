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

      # GitHub personal access tokens (classic and fine-grained)
      # Matches: ghp_abc123..., gho_abc123..., github_pat_abc123...
      GITHUB_TOKEN_PATTERN = /\b(?:ghp|gho|ghs|ghr|github_pat)_[A-Za-z0-9_]{20,}\b/

      # GitLab personal/project/group access tokens
      # Matches: glpat-xxxxxxxxxxxxxxxxxxxx
      GITLAB_TOKEN_PATTERN = /\bglpat-[A-Za-z0-9\-_]{20,}\b/

      # Slack tokens and webhook URLs
      # Matches: xoxb-..., xoxp-..., xoxa-..., xoxs-... and hooks.slack.com webhook URLs
      SLACK_TOKEN_PATTERN = /\bxox[bpas]-[A-Za-z0-9\-]{10,}\b/
      SLACK_WEBHOOK_PATTERN = %r{hooks\.slack\.com/services/[A-Za-z0-9/]{40,}}

      # Azure storage/service bus connection strings (keyword-gated)
      # Matches: AccountKey=base64value..., SharedAccessSignature=sv=...
      AZURE_SECRET_PATTERN = /\b(?:AccountKey|SharedAccessSignature)\s*=\s*[A-Za-z0-9+\/=&%]{20,}/i

      PATTERNS = [
        [ BEARER_TOKEN_PATTERN,     :secret ],
        [ API_KEY_PATTERN,          :secret ],
        [ OPENAI_KEY_PATTERN,       :secret ],
        [ SECRET_ASSIGNMENT_PATTERN, :secret ],
        [ AWS_KEY_PATTERN,          :secret ],
        [ GITHUB_TOKEN_PATTERN,     :secret ],
        [ GITLAB_TOKEN_PATTERN,     :secret ],
        [ SLACK_TOKEN_PATTERN,      :secret ],
        [ SLACK_WEBHOOK_PATTERN,    :secret ],
        [ AZURE_SECRET_PATTERN,     :secret ]
      ].freeze

      def call
        PATTERNS.flat_map { |pattern, type| scan_findings(pattern, type) }
      end
    end
  end
end
