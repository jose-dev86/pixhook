# Delivers one outbox event to the merchant endpoint.
# Idempotent: delivered/dead events are skipped, so retries and duplicate enqueues are safe.
# Any non-2xx or network error raises, letting Sidekiq retry with exponential backoff.
class WebhookDeliveryJob
  include Sidekiq::Job

  MAX_RETRIES = 8
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  class DeliveryFailed < StandardError; end

  sidekiq_options queue: "webhooks", retry: MAX_RETRIES

  sidekiq_retry_in { |count| (2**count) + rand(5) }

  sidekiq_retries_exhausted do |job, exception|
    event = WebhookEvent.find_by(id: job["args"].first)
    event&.update!(status: :dead, last_error: exception.message.truncate(500))
  end

  def perform(webhook_event_id)
    event = WebhookEvent.includes(:merchant).find_by(id: webhook_event_id)
    return if event.nil? || !event.pending?

    merchant = event.merchant
    return event.update!(status: :dead, last_error: "merchant has no webhook_url") if merchant.webhook_url.blank?

    deliver(event, merchant)
  end

  private

  def deliver(event, merchant)
    body = event.payload.to_json
    event.increment!(:attempts)

    response = connection.post(merchant.webhook_url) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["X-PixHook-Event"] = event.event_type
      req.headers["X-PixHook-Delivery"] = event.id.to_s
      req.headers["X-PixHook-Signature"] = WebhookSignature.header(secret: merchant.webhook_secret, body:)
      req.body = body
    end

    record_response(event, response)
  rescue Faraday::Error => e
    event.update!(last_error: "#{e.class}: #{e.message}".truncate(500))
    raise DeliveryFailed, e.message
  end

  def record_response(event, response)
    if response.success?
      event.update!(status: :delivered, delivered_at: Time.current, last_response_code: response.status, last_error: nil)
    else
      event.update!(last_response_code: response.status, last_error: "HTTP #{response.status}")
      raise DeliveryFailed, "HTTP #{response.status}"
    end
  end

  def connection
    Faraday.new(request: { open_timeout: OPEN_TIMEOUT, timeout: READ_TIMEOUT })
  end
end
