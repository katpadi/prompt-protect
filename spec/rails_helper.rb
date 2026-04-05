require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

RSpec.configure do |config|
  config.use_active_record = false

  # Stub the spaCy sidecar globally — no running container needed.
  # Override locally in examples that need specific NER results.
  config.before(:each) do
    stub_request(:post, /spacy:5001\/detect/)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { entities: [] }.to_json
      )
  end

  # Temporarily set env vars for the duration of an example, then restore.
  # Handles nil originals correctly (deletes the key rather than setting nil).
  #
  #   around { |ex| with_env("KEY" => "value") { ex.run } }
  #   with_env("KEY" => "value") { subject.call }
  config.include(Module.new do
    def with_env(overrides, &block)
      originals = overrides.keys.each_with_object({}) { |k, h| h[k] = ENV[k] }
      overrides.each { |k, v| ENV[k] = v }
      block.call
    ensure
      originals.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    end
  end)

  config.filter_rails_from_backtrace!
end
