class HealthController < ApplicationController
  def show
    render json: {
      status:   "ok",
      service:  "prompt-protect",
      checks:   {
        app: { status: "ok" },
        ner: ner_check
      }
    }
  end

  private

  def ner_check
    return { status: "disabled" } unless ner_enabled?

    response = Faraday.get("#{ner_url}/health")
    body     = JSON.parse(response.body)
    { status: "ok", backend: body["backend"], model: body["model"] }
  rescue Faraday::Error, JSON::ParserError => e
    { status: "unreachable", error: e.message }
  end

  def ner_enabled?
    ENV.fetch("NER_ENABLED", "true") != "false"
  end

  def ner_url
    ENV.fetch("NER_SERVICE_URL", "http://spacy:5001")
  end
end
