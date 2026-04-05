require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.to_s + "/swagger"

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Prompt Protect API",
        version: "v1",
        description: <<~DESC
          Prompt Protect is a drop-in safety proxy for LLM calls.

          It sits between your backend and an LLM provider to detect PII, assess risk,
          and enforce policy before the prompt leaves your infrastructure.

          **Pipeline:** detect → assess risk → apply policy → (optionally mask) → forward
        DESC
      },
      servers: [
        { url: "http://localhost:3000", description: "Local (Docker)" }
      ]
    }
  }

  config.openapi_format = :yaml
end
