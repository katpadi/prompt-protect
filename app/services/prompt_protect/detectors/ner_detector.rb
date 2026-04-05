module PromptProtect
  module Detectors
    class NerDetector < BaseDetector
      # spaCy labels we care about and their mapping to our types
      # GPE = geopolitical entity (countries, cities, states)
      # LOC = non-GPE locations (mountains, rivers, regions)
      LABEL_MAP = {
        "PERSON" => :person,
        "ORG"    => :org,
        "GPE"    => :location,
        "LOC"    => :location
      }.freeze

      def call
        response = client.post("/detect") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = { text: @text }.to_json
        end

        parse_entities(JSON.parse(response.body))
      rescue Faraday::Error => e
        Rails.logger.warn("[NerDetector] spaCy service unavailable (#{e.message}), falling back to PersonDetector")
        PersonDetector.new(@text).call
      end

      private

      def parse_entities(body)
        body.fetch("entities", []).filter_map do |entity|
          type = LABEL_MAP[entity["label"]]
          next unless type

          { type: type, value: entity["text"], start: entity["start"], end: entity["end"] }
        end
      end

      def client
        Faraday.new(url: service_url) do |f|
          f.options.timeout      = 5
          f.options.open_timeout = 2
        end
      end

      def service_url
        ENV.fetch("SPACY_SERVICE_URL", "http://spacy:5001")
      end
    end
  end
end
