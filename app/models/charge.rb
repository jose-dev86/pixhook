class Charge < ApplicationRecord
  DEFAULT_TTL = 30.minutes

  belongs_to :merchant
  has_many :webhook_events, dependent: :destroy

  enum :status, { pending: "pending", paid: "paid", expired: "expired", refunded: "refunded" },
       validate: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, :request_fingerprint, :txid, :expires_at, presence: true
  validates :description, length: { maximum: 140 }

  before_validation :assign_defaults, on: :create

  after_create_commit :schedule_expiration
  after_commit :broadcast_to_panel

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :with_status, ->(status) { status.present? && statuses.key?(status) ? where(status:) : all }

  class InvalidTransition < StandardError; end

  def pay!
    transition!(from: :pending, to: :paid, event: "charge.paid") { self.paid_at = Time.current }
  end

  def refund!
    transition!(from: :paid, to: :refunded, event: "charge.refunded") { self.refunded_at = Time.current }
  end

  def expire!
    transition!(from: :pending, to: :expired, event: "charge.expired")
  end

  def due_for_expiration?
    pending? && expires_at <= Time.current
  end

  def pix_copy_paste
    PixBrCode.call(amount_cents:, txid:)
  end

  def amount
    amount_cents / 100.0
  end

  def as_api_json
    {
      id: id,
      txid: txid,
      status: status,
      amount_cents: amount_cents,
      description: description,
      pix_copy_paste: pix_copy_paste,
      expires_at: expires_at.iso8601,
      paid_at: paid_at&.iso8601,
      refunded_at: refunded_at&.iso8601,
      created_at: created_at.iso8601
    }
  end

  private

  # State change and outbox event are written in the same transaction:
  # the webhook is only enqueued after commit (see WebhookEvent), never inside the transaction.
  def transition!(from:, to:, event:)
    with_lock do
      raise InvalidTransition, "cannot go from #{status} to #{to} (expected #{from})" unless status == from.to_s

      yield if block_given?
      update!(status: to)
      webhook_events.create!(merchant: merchant, event_type: event, payload: { event: event, data: as_api_json })
    end
    self
  end

  def assign_defaults
    self.txid ||= SecureRandom.alphanumeric(32)
    self.expires_at ||= DEFAULT_TTL.from_now
  end

  def schedule_expiration
    ExpireChargeJob.perform_at(expires_at, id)
  end

  def broadcast_to_panel
    broadcast_replace_later_to "charges", target: self, partial: "charges/row", locals: { charge: self }
    broadcast_replace_later_to self, target: "charge_summary", partial: "charges/summary", locals: { charge: self }
  end
end
