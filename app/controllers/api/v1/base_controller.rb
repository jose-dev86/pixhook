module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_merchant!
      rate_limit to: 60, within: 1.minute, by: -> { request.authorization.to_s }, with: -> { render_error(:too_many_requests, "rate limit exceeded") }

      rescue_from ActiveRecord::RecordNotFound, with: -> { render_error(:not_found, "not found") }
      rescue_from ActionController::ParameterMissing, with: ->(e) { render_error(:bad_request, e.message) }
      rescue_from Charge::InvalidTransition, with: ->(e) { render_error(:unprocessable_content, e.message) }

      private

      attr_reader :current_merchant

      def authenticate_merchant!
        @current_merchant = authenticate_with_http_token { |token, _| Merchant.authenticate(token) }
        render_error(:unauthorized, "invalid or missing API key") unless @current_merchant
      end

      def render_error(status, message, details: nil)
        render json: { error: { message:, details: }.compact }, status:
      end
    end
  end
end
