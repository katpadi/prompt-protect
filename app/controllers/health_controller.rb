class HealthController < ApplicationController
  def show
    render json: { status: "ok", service: "prompt-protect" }
  end
end
