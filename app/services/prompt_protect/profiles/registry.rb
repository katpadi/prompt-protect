module PromptProtect
  module Profiles
    module Registry
      PROFILES = {
        "default" => {
          name: "default",
          description: "General protection profile",
          policy_overrides: {},
          restore_output: false
        },
        "lenient" => {
          name: "lenient",
          description: "Sanitizes instead of blocking high-risk content; restores placeholders in output",
          policy_overrides: { high: :sanitize },
          restore_output: true
        }
      }.freeze

      def self.find(name)
        PROFILES.fetch(name.to_s) do
          raise ArgumentError, "Unknown profile: #{name.inspect}. Available: #{PROFILES.keys.join(', ')}"
        end
      end

      def self.all
        PROFILES.values.map { |p| p.slice(:name, :description) }
      end
    end
  end
end
