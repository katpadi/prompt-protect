module PromptProtect
  class PolicyEngine
    ACTIONS = %i[allow sanitize block].freeze

    DEFAULTS = {
      low: :allow,
      medium: :sanitize,
      high: :block
    }.freeze

    def initialize(risk_level)
      @risk_level = risk_level
    end

    def call
      action = policy.fetch(@risk_level) do
        raise ArgumentError, "Unknown risk level: #{@risk_level.inspect}"
      end

      unless ACTIONS.include?(action)
        raise ArgumentError, "Invalid policy action #{action.inspect} for risk level #{@risk_level.inspect}"
      end

      action
    end

    private

    def policy
      @policy ||= DEFAULTS.merge(overrides_from_env)
    end

    def overrides_from_env
      DEFAULTS.keys.each_with_object({}) do |level, overrides|
        env_key = "PROMPT_PROTECT_POLICY_#{level.to_s.upcase}"
        raw = ENV[env_key]
        next unless raw

        action = raw.strip.downcase.to_sym
        unless ACTIONS.include?(action)
          raise ArgumentError, "Invalid value for #{env_key}: #{raw.inspect}. Must be one of: #{ACTIONS.join(', ')}"
        end

        overrides[level] = action
      end
    end
  end
end
