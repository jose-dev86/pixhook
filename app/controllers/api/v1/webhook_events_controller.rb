module Api
  module V1
    class WebhookEventsController < BaseController
      def index
        events = current_merchant.webhook_events.order(id: :desc).limit(50)
        render json: { data: events.as_json(only: %i[id charge_id event_type status attempts last_response_code last_error delivered_at created_at]) }
      end

      def redeliver
        event = current_merchant.webhook_events.find(params[:id])
        event.redeliver!
        render json: { id: event.id, status: event.status }, status: :accepted
      end
    end
  end
end
