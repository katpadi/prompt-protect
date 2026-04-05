class HealthController < ApplicationController
  def show
    render json: {
      status:   "ok",
      service:  "prompt-protect",
      checks:   {
        app:   { status: "ok" },
        spacy: spacy_check
      }
    }
  end

  private

  def spacy_check
    return { status: "disabled" } unless spacy_enabled?

    response = Faraday.get("#{spacy_url}/health")
    body     = JSON.parse(response.body)
    { status: "ok", model: body["model"] }
  rescue Faraday::Error, JSON::ParserError => e
    { status: "unreachable", error: e.message }
  end

  def spacy_enabled?
    ENV.fetch("SPACY_ENABLED", "true") != "false"
  end

  def spacy_url
    ENV.fetch("SPACY_SERVICE_URL", "http://spacy:5001")
  end
end
