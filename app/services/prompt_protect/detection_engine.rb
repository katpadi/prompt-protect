module PromptProtect
  class DetectionEngine
    REGEX_DETECTORS = [
      Detectors::EmailDetector,
      Detectors::PhoneDetector,
      Detectors::AddressDetector,
      Detectors::IdDetector,
      Detectors::IpDetector,
      Detectors::SecretDetector,
      Detectors::DobDetector,
      Detectors::MedicalDetector,
      Detectors::FinancialDetector
    ].freeze

    def initialize(text)
      @text = TextNormalizer.new(text).call
    end

    def call
      (regex_findings + person_findings)
        .sort_by { |finding| finding[:start] }
    end

    private

    def regex_findings
      REGEX_DETECTORS.flat_map { |klass| klass.new(@text).call }
    end

    def person_findings
      person_detector.new(@text).call
    end

    def person_detector
      spacy_enabled? ? Detectors::NerDetector : Detectors::PersonDetector
    end

    def spacy_enabled?
      ENV.fetch("NER_ENABLED", "true") != "false"
    end
  end
end
