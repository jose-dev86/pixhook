module Demo
  # Example merchant endpoint used by the demo merchant: verifies the signature like a real integration would.
  class WebhookReceiverController < ActionController::API
    def create
      merchant = Merchant.find(params[:merchant_id])
      body = request.raw_post

      if WebhookSignature.valid?(secret: merchant.webhook_secret, body:, header: request.headers["X-PixHook-Signature"])
        Rails.logger.info(event: "demo.webhook_received", merchant_id: merchant.id, type: request.headers["X-PixHook-Event"])
        head :no_content
      else
        head :unauthorized
      end
    end
  end
end
