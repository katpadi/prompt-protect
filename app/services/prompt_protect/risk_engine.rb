module PromptProtect
  class RiskEngine
    LEVELS = %i[low medium high].freeze

    CRITICAL_TYPES  = %i[id secret medical financial].freeze
    SENSITIVE_TYPES = %i[email phone address ip dob].freeze

    # Mosaic profile types — individually low/medium, but assembling 3+ of these
    # in a single prompt produces a complete enough identity profile to be high risk.
    # Competitors score fields in isolation; we score the combination.
    MOSAIC_TYPES     = %i[person org location email phone dob].freeze
    MOSAIC_THRESHOLD = 3

    Result = Struct.new(:level, :explanation, keyword_init: true)

    def initialize(findings)
      @findings = findings
    end

    def call
      detected_types = @findings.map { |f| f[:type] }.uniq

      level, rule, reason, threshold = score(detected_types)

      explanation = {
        rule:            rule,
        reason:          reason,
        triggered_by:    (detected_types & relevant_types(rule)).map(&:to_s),
        detected_values: detected_values_for(rule),
        threshold:       threshold
      }

      Result.new(level: level, explanation: explanation)
    end

    private

    def score(types)
      if types.empty?
        [ :low, "clean", "No sensitive data detected.", nil ]
      elsif critical?(types)
        critical = types & CRITICAL_TYPES
        [ :high, "critical_type",
          "Prompt contains a critical-risk entity (#{critical.map(&:to_s).join(', ')}) that is blocked by policy.",
          nil ]
      elsif identity_reconstruction?(types)
        [ :high, "identity_reconstruction",
          "Name and date of birth together are sufficient to reconstruct identity.",
          nil ]
      elsif mosaic_profile?(types)
        mosaic = types & MOSAIC_TYPES
        [ :high, "mosaic_profile",
          "#{mosaic.size} profile fragments (#{mosaic.map(&:to_s).join(', ')}) combine into a complete identity profile.",
          MOSAIC_THRESHOLD ]
      elsif multiple_sensitive?(types)
        sensitive = types & SENSITIVE_TYPES
        [ :high, "multiple_sensitive",
          "#{sensitive.size} sensitive types detected together (#{sensitive.map(&:to_s).join(', ')}).",
          2 ]
      elsif any_sensitive?(types)
        sensitive = (types & SENSITIVE_TYPES).first
        [ :medium, "single_sensitive",
          "One sensitive type detected (#{sensitive}).",
          nil ]
      elsif person_with_context?(types)
        context = (types & %i[org location]).map(&:to_s).join(", ")
        [ :medium, "person_with_context",
          "Person name combined with #{context} reveals affiliation or whereabouts.",
          nil ]
      elsif person_only?(types)
        [ :low, "person_only",
          "Only a person name was detected — low risk on its own.",
          nil ]
      else
        [ :low, "clean", "No sensitive data detected.", nil ]
      end
    end

    def relevant_types(rule)
      case rule
      when "critical_type"           then CRITICAL_TYPES
      when "identity_reconstruction" then %i[dob person]
      when "mosaic_profile"          then MOSAIC_TYPES
      when "multiple_sensitive"      then SENSITIVE_TYPES
      when "single_sensitive"        then SENSITIVE_TYPES
      when "person_with_context"     then %i[person org location]
      when "person_only"             then %i[person]
      else                                []
      end
    end

    def detected_values_for(rule)
      relevant = relevant_types(rule)
      @findings
        .select { |f| relevant.include?(f[:type]) }
        .map { |f| f[:value] }
        .uniq
    end

    def critical?(types)              = (types & CRITICAL_TYPES).any?
    def identity_reconstruction?(types) = types.include?(:dob) && types.include?(:person)
    def mosaic_profile?(types)        = (types & MOSAIC_TYPES).size >= MOSAIC_THRESHOLD
    def multiple_sensitive?(types)    = (types & SENSITIVE_TYPES).size >= 2
    def any_sensitive?(types)         = (types & SENSITIVE_TYPES).any?
    def person_with_context?(types)   = types.include?(:person) && (types.include?(:org) || types.include?(:location))
    def person_only?(types)           = types == %i[person]
  end
end
