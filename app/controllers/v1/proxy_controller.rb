module V1
  class ProxyController < ApplicationController
    rescue_from PromptProtect::Forwarder::UpstreamError, with: :render_upstream_error

    def create
      findings_by_message = request_messages.map { |msg| analyze(msg) }
      all_findings        = findings_by_message.flat_map { |r| r[:findings] }
      risk_result         = PromptProtect::RiskEngine.new(all_findings).call
      action              = PromptProtect::PolicyEngine.new(risk_result.level).call

      set_transparency_headers(risk_level: risk_result.level, action: action, findings: all_findings)

      return render_dry_run(findings_by_message, all_findings, risk_result, action) if dry_run?

      case action
      when :block    then render_blocked(risk_result)
      when :sanitize then forward(sanitized_payload(findings_by_message), risk_result)
      when :allow    then forward(request_payload, risk_result)
      end
    end

    private

    def dry_run?
      request_payload["dry_run"] == true
    end

    def request_payload
      @request_payload ||= JSON.parse(request.body.read)
    end

    def request_messages
      request_payload.fetch("messages", [])
    end

    def analyze(message)
      content = message["content"].to_s
      { message: message, findings: PromptProtect::DetectionEngine.new(content).call }
    end

    def sanitized_payload(findings_by_message)
      masked_messages = findings_by_message.map do |result|
        content = result[:message]["content"].to_s
        masked  = PromptProtect::MaskingEngine.new(content, result[:findings]).call
        result[:message].merge("content" => masked[:masked_text])
      end

      request_payload.merge("messages" => masked_messages)
    end

    def forward(payload, risk_result)
      result = PromptProtect::Forwarder.new(payload).call
      body   = scan_and_sanitize_response(result[:body])
      body   = body.merge("risk_explanation" => risk_result.explanation)
      render json: body, status: result[:status]
    end

    def scan_and_sanitize_response(body)
      choices = body["choices"] || []
      all_findings = []

      sanitized_choices = choices.map do |choice|
        content = choice.dig("message", "content").to_s
        next choice if content.empty?

        findings = PromptProtect::DetectionEngine.new(content).call
        all_findings.concat(findings)
        next choice if findings.empty?

        masked = PromptProtect::MaskingEngine.new(content, findings).call
        choice.deep_merge("message" => { "content" => masked[:masked_text] })
      end

      set_response_scan_headers(all_findings)
      body.merge("choices" => sanitized_choices)
    end

    def set_response_scan_headers(findings)
      risk_result = PromptProtect::RiskEngine.new(findings).call
      types       = findings.map { |f| f[:type] }.uniq.map(&:to_s)

      response.set_header("X-Prompt-Protect-Response-Risk-Level", risk_result.level.to_s)
      response.set_header("X-Prompt-Protect-Response-Detected-Types", types.join(","))
      response.set_header("X-Prompt-Protect-Response-Masked", findings.any?.to_s)
    end

    def render_dry_run(findings_by_message, all_findings, risk_result, action)
      messages = findings_by_message.map do |result|
        content = result[:message]["content"].to_s
        masked  = PromptProtect::MaskingEngine.new(content, result[:findings]).call

        {
          role:          result[:message]["role"],
          original_text: content,
          masked_text:   masked[:masked_text],
          mapping:       masked[:mapping],
          findings:      result[:findings]
        }
      end

      render json: {
        dry_run:         true,
        risk_level:      risk_result.level,
        action:          action,
        risk_explanation: risk_result.explanation,
        messages:        messages
      }
    end

    def set_transparency_headers(risk_level:, action:, findings:)
      response.set_header("X-Prompt-Protect-Risk-Level", risk_level.to_s)
      response.set_header("X-Prompt-Protect-Action", action.to_s)
      response.set_header("X-Prompt-Protect-Detected-Types", detected_types_header(findings))
      response.set_header("X-Prompt-Protect-Masked", (action == :sanitize).to_s)
    end

    def detected_types_header(findings)
      findings.map { |f| f[:type] }.uniq.map(&:to_s).join(",")
    end

    def render_blocked(risk_result)
      render json: {
        error: {
          type:            "blocked",
          message:         "Request blocked: high risk content detected",
          risk_level:      risk_result.level,
          risk_explanation: risk_result.explanation
        }
      }, status: 422
    end

    def render_upstream_error(error)
      render json: {
        error: { type: "upstream_error", message: error.message, body: error.body }
      }, status: :bad_gateway
    end
  end
end
