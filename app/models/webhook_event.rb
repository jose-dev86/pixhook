class WebhookEvent < ApplicationRecord
  belongs_to :merchant
  belongs_to :charge

  enum :status, { pending: "pending", delivered: "delivered", dead: "dead" }, validate: true

  validates :event_type, presence: true

  # Outbox: the row is committed together with the state change; delivery starts after commit.
  after_create_commit :enqueue_delivery
  after_commit :broadcast_to_panel

  scope :recent_first, -> { order(id: :desc) }

  def enqueue_delivery
    WebhookDeliveryJob.perform_async(id)
  end

  def broadcast_to_panel
    broadcast_replace_later_to "webhook_events", target: self, partial: "webhook_events/row", locals: { event: self }
    broadcast_replace_later_to charge, target: "charge_deliveries", partial: "charges/deliveries", locals: { charge: }
    broadcast_replace_later_to "charges", target: charge, partial: "charges/row", locals: { charge: }
  end

  def redeliver!
    update!(status: :pending, last_error: nil)
    enqueue_delivery
  end
end
