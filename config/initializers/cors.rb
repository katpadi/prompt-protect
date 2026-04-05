Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "*")

    resource "*",
      headers: :any,
      methods: [ :get, :post, :options, :head ],
      expose: %w[
        X-Prompt-Protect-Risk-Level
        X-Prompt-Protect-Action
        X-Prompt-Protect-Detected-Types
        X-Prompt-Protect-Masked
        X-Prompt-Protect-Response-Risk-Level
        X-Prompt-Protect-Response-Detected-Types
        X-Prompt-Protect-Response-Masked
      ]
  end
end
