module PromptProtect
  class MaskingEngine
    def initialize(text, findings)
      @text = text
      @findings = findings
    end

    # Returns { masked_text: String, mapping: Hash }
    # mapping: { "[EMAIL_1]" => "john@example.com", ... }
    def call
      return { masked_text: @text, mapping: {} } if @findings.empty?

      numbered = number_findings(sorted_non_overlapping)
      mapping = {}
      masked = @text.dup

      # Replace from right to left so earlier offsets remain valid
      numbered.reverse_each do |finding|
        mapping[finding[:placeholder]] = finding[:value]
        masked[finding[:start]...finding[:end]] = finding[:placeholder]
      end

      { masked_text: masked, mapping: mapping }
    end

    private

    def sorted_non_overlapping
      sorted = @findings.sort_by { |f| f[:start] }

      sorted.each_with_object([]) do |finding, kept|
        last = kept.last
        kept << finding if last.nil? || finding[:start] >= last[:end]
      end
    end

    def number_findings(findings)
      counters = Hash.new(0)

      findings.map do |finding|
        type_key = finding[:type].to_s.upcase
        counters[type_key] += 1
        finding.merge(placeholder: "[#{type_key}_#{counters[type_key]}]")
      end
    end
  end
end
