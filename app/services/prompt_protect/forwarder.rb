module PromptProtect
  class Forwarder
    class UpstreamError < StandardError
      attr_reader :status, :body

      def initialize(status, body)
        @status = status
        @body   = body
        super("Upstream returned #{status}")
      end
    end

    def initialize(payload)
      provider  = payload["provider"] || ENV.fetch("PROMPT_PROTECT_PROVIDER", Providers::Registry::DEFAULT)
      model     = payload["model"]    || ENV.fetch("PROMPT_PROTECT_MODEL", nil)
      @payload  = payload.except("provider").merge(model ? { "model" => model } : {})
      @adapter  = Providers::Registry.adapter_for(provider).new(@payload)
    end

    def call
      response = connection.post(@adapter.endpoint) do |req|
        req.headers["Content-Type"] = "application/json"
        @adapter.request_headers.each { |k, v| req.headers[k] = v }
        req.body = @adapter.build_request.to_json
      end

      parsed = JSON.parse(response.body)
      raise UpstreamError.new(response.status, parsed) unless response.success?

      { status: response.status, body: @adapter.parse_response(parsed) }
    rescue Faraday::Error => e
      raise UpstreamError.new(502, { "error" => { "message" => e.message } })
    end

    private

    def connection
      Faraday.new(url: @adapter.base_url) do |f|
        f.options.timeout      = 30
        f.options.open_timeout = 5
      end
    end
  end
end
