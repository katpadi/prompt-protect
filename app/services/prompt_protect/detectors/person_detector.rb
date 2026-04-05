module PromptProtect
  module Detectors
    class PersonDetector < BaseDetector
      # Honorific + one or more capitalized words: Dr. Jane Smith, Mr. John
      HONORIFIC_PATTERN = /\b(?:Mr|Mrs|Ms|Miss|Dr|Prof)\.?\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*/

      # Individual capitalized word (min 3 chars) for adjacent-pair detection
      CAPITALIZED_WORD_PATTERN = /\b[A-Z][a-z]{2,}\b/

      # Name followed by a single initial: "Kat P." or "Kat P"
      NAME_THEN_INITIAL_PATTERN = /\b([A-Z][a-z]{2,})\s+([A-Z])\.(?=\s|$|\W)/

      # Initial followed by a name: "J. Smith" or "K. Johnson"
      INITIAL_THEN_NAME_PATTERN = /\b([A-Z])\.\s+([A-Z][a-z]{2,})\b/

      # Words that are commonly capitalised but are never part of a person's name.
      # Covers legal/contract defined terms, months, days, directions, address suffixes,
      # sentence-starters, and other high-frequency false-positive triggers.
      NON_NAME_WORDS = Set.new(%w[
        This The These Those That
        Each Every Any All Some Such Other Another
        Upon Which Where When What Who
        Agreement Contract Document Terms Conditions Policy Schedule Exhibit Annex Appendix
        Loan Vehicle Payment Interest Rate Default Insurance Security Ownership
        Party Lender Borrower Guarantor Mortgagor Mortgagee Lessor Lessee
        Section Article Clause Subsection Paragraph
        Date Signed Witness Signature
        January February March April May June July August September October November December
        Monday Tuesday Wednesday Thursday Friday Saturday Sunday
        Street Avenue Road Boulevard Drive Lane Court Way Place Crescent Parade
        New South North East West Central Upper Lower
        Make Model Registration
        First Second Third Fourth Fifth
        Early Full Part Entire
        Law Governing Repayment Ownership
        Australia
        Toyota Honda Ford Nissan Mazda Subaru Hyundai Kia Volkswagen Audi Mercedes Bmw
        Corolla Camry Civic Accord Hilux Ranger Patrol Prado Outlander
      ].map(&:downcase)).freeze

      def call
        honorific_findings    = scan_findings(HONORIFIC_PATTERN, :person)
        full_name_findings    = find_adjacent_name_pairs
        initial_name_findings = find_initial_name_pairs

        deduplicate(honorific_findings + full_name_findings + initial_name_findings)
      end

      private

      # Collects all capitalized words then pairs adjacent ones (allows overlapping pairs
      # like "John Smith" and "Smith Jones" in "John Smith Jones").
      # Words in NON_NAME_WORDS are excluded from both positions of the pair.
      def find_adjacent_name_pairs
        words = []
        @text.scan(CAPITALIZED_WORD_PATTERN) do
          md = Regexp.last_match
          words << { value: md[0], start: md.begin(0), end: md.end(0) }
        end

        words.each_cons(2).filter_map do |a, b|
          between = @text[a[:end]...b[:start]]
          next unless between.match?(/\A\s+\z/)
          next if non_name?(a[:value]) || non_name?(b[:value])

          { type: :person, value: "#{a[:value]} #{b[:value]}", start: a[:start], end: b[:end] }
        end
      end

      def find_initial_name_pairs
        findings = []

        @text.scan(NAME_THEN_INITIAL_PATTERN) do
          md = Regexp.last_match
          next if non_name?(md[1])
          findings << { type: :person, value: "#{md[1]} #{md[2]}.", start: md.begin(0), end: md.end(0) }
        end

        @text.scan(INITIAL_THEN_NAME_PATTERN) do
          md = Regexp.last_match
          next if non_name?(md[2])
          findings << { type: :person, value: "#{md[1]}. #{md[2]}", start: md.begin(0), end: md.end(0) }
        end

        findings
      end

      def non_name?(word)
        NON_NAME_WORDS.include?(word.downcase)
      end

      # Remove findings whose range is fully covered by another finding
      def deduplicate(findings)
        findings.reject do |candidate|
          findings.any? do |other|
            other != candidate &&
              other[:start] <= candidate[:start] &&
              other[:end] >= candidate[:end]
          end
        end
      end
    end
  end
end
