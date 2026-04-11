module V1
  class ProxyController < ApplicationController
    rescue_from PromptProtect::Forwarder::UpstreamError, with: :render_upstream_error

    def create
      pp_opts   = prompt_protect_opts
      profile   = PromptProtect::Profiles::Registry.find(pp_opts["profile"] || "default")
      overrides = profile[:policy_overrides].merge(inline_policy_overrides(pp_opts))
      opts      = resolve_opts(pp_opts, profile)

      findings_by_message = request_messages.map { |msg| analyze(msg) }
      all_findings        = findings_by_message.flat_map { |r| r[:findings] }
      risk_result         = PromptProtect::RiskEngine.new(all_findings).call
      action              = PromptProtect::PolicyEngine.new(risk_result.level, overrides: overrides).call

      set_transparency_headers(risk_level: risk_result.level, action: action, findings: all_findings)

      return render_dry_run(findings_by_message, all_findings, risk_result, action) if dry_run?

      case action
      when :block
        render_blocked(risk_result)
      when :sanitize
        masked = build_masked_payload(findings_by_message)
        forward(masked[:payload], risk_result,
                mapping: masked[:combined_mapping],
                action: action,
                all_findings: all_findings,
                opts: opts)
      when :allow
        forward(request_payload, risk_result,
                action: action,
                all_findings: all_findings,
                opts: opts)
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

    def prompt_protect_opts
      request_payload.fetch("prompt_protect", {})
    end

    def inline_policy_overrides(pp_opts)
      return {} unless pp_opts["policy_overrides"].is_a?(Hash)
      pp_opts["policy_overrides"].transform_keys(&:to_sym).transform_values(&:to_sym)
    end

    def resolve_opts(pp_opts, profile)
      restore = pp_opts.key?("restore_output") ? pp_opts["restore_output"] : profile[:restore_output]
      {
        profile:          profile[:name],
        restore_output:   restore,
        include_findings: pp_opts.fetch("include_findings", false)
      }
    end

    def analyze(message)
      content = message["content"].to_s
      { message: message, findings: PromptProtect::DetectionEngine.new(content).call }
    end

    def build_masked_payload(findings_by_message)
      combined_mapping = {}

      masked_messages = findings_by_message.map do |result|
        content = result[:message]["content"].to_s
        masked  = PromptProtect::MaskingEngine.new(content, result[:findings]).call
        combined_mapping.merge!(masked[:mapping])
        result[:message].merge("content" => masked[:masked_text])
      end

      { payload: request_payload.merge("messages" => masked_messages), combined_mapping: combined_mapping }
    end

    def forward(payload, risk_result, mapping: {}, action: nil, all_findings: [], opts: {})
      result = PromptProtect::Forwarder.new(payload).call

      if opts[:restore_output]
        # Scan response for transparency headers but do not mask content —
        # the caller wants real values back. If the input was sanitized,
        # restore placeholders; if it was allowed, the LLM already has real
        # values and masking them would break the restore contract.
        body = scan_response_no_mask(result[:body])
        body = restore_response(body, mapping) if mapping.any?
      else
        body = scan_and_sanitize_response(result[:body])
      end
      body    = body.merge("risk_explanation" => risk_result.explanation)
      body    = body.merge("prompt_protect" => build_pp_metadata(opts, action, all_findings, mapping.any?)) if opts[:include_findings]
      render json: body, status: result[:status]
    end

    def restore_response(body, mapping)
      choices = body["choices"] || []

      restored_choices = choices.map do |choice|
        content = choice.dig("message", "content").to_s
        next choice if content.empty?

        restored = mapping.reduce(content) { |text, (placeholder, original)| text.gsub(placeholder, original) }
        choice.deep_merge("message" => { "content" => restored })
      end

      body.merge("choices" => restored_choices)
    end

    def build_pp_metadata(opts, action, all_findings, restored)
      type_counts = all_findings.group_by { |f| f[:type].to_s }.transform_values(&:count)
      {
        profile:          opts[:profile],
        action:           action.to_s,
        restored:         opts[:restore_output] && restored,
        findings_summary: type_counts
      }
    end

    def scan_response_no_mask(body)
      choices      = body["choices"] || []
      all_findings = choices.flat_map do |choice|
        content = choice.dig("message", "content").to_s
        content.empty? ? [] : PromptProtect::DetectionEngine.new(content).call
      end
      set_response_scan_headers(all_findings)
      body
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
        dry_run:          true,
        risk_level:       risk_result.level,
        action:           action,
        risk_explanation: risk_result.explanation,
        messages:         messages
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
          type:             "blocked",
          message:          "Request blocked: high risk content detected",
          risk_level:       risk_result.level,
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
