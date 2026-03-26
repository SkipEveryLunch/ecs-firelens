class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok" }
  rescue => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end
end
