module Api
  module V1
    class ChargesController < BaseController
      PER_PAGE = 20

      def index
        charges = current_merchant.charges.recent_first.limit(PER_PAGE)
        charges = charges.where(id: ...params[:before_id].to_i) if params[:before_id].present?
        render json: { data: charges.map(&:as_api_json) }
      end

      def show
        render json: charge.as_api_json
      end

      def create
        result = CreateCharge.call(
          merchant: current_merchant,
          idempotency_key: request.headers["Idempotency-Key"],
          params: charge_params
        )
        return render_create_error(result) unless result.success?

        response.headers["Idempotent-Replayed"] = (!result.created).to_s
        render json: result.charge.as_api_json, status: result.created ? :created : :ok
      end

      def pay
        render json: charge.pay!.as_api_json
      end

      def refund
        render json: charge.refund!.as_api_json
      end

      private

      def charge
        @charge ||= current_merchant.charges.find_by!(txid: params[:id])
      end

      def charge_params
        params.expect(charge: [ :amount_cents, :description ])
      end

      def render_create_error(result)
        case result.error
        when :missing_idempotency_key then render_error(:bad_request, "Idempotency-Key header is required")
        when :idempotency_conflict then render_error(:conflict, "Idempotency-Key already used with a different payload")
        else render_error(:unprocessable_content, "invalid charge", details: result.charge.errors.to_hash)
        end
      end
    end
  end
end
