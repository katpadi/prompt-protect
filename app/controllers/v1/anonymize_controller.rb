module V1
  class AnonymizeController < ApplicationController
    def create
      text     = anonymize_params["text"].to_s
      findings = PromptProtect::DetectionEngine.new(text).call
      masked   = PromptProtect::MaskingEngine.new(text, findings).call

      render json: {
        sanitized_text: masked[:masked_text],
        findings:       findings
      }
    end

    private

    def anonymize_params
      @anonymize_params ||= JSON.parse(request.body.read)
    end
  end
end
