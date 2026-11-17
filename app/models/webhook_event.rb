class WebhookEvent < ApplicationRecord
  belongs_to :merchant
  belongs_to :charge

  enum :status, { pending: "pending", delivered: "delivered", dead: "dead" }, validate: true

  validates :event_type, presence: true

  # Outbox: the row is committed together with the state change; delivery starts after commit.
  after_create_commit :enqueue_delivery

  def enqueue_delivery
    WebhookDeliveryJob.perform_async(id)
  end

  def redeliver!
    update!(status: :pending, last_error: nil)
    enqueue_delivery
  end
end
