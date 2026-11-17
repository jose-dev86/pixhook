class Merchant < ApplicationRecord
  has_many :charges, dependent: :restrict_with_error
  has_many :webhook_events, dependent: :restrict_with_error

  validates :name, presence: true
  validate :webhook_url_must_be_http

  before_validation :generate_webhook_secret, on: :create

  # Returns [merchant, plain_api_key]. Only the SHA-256 digest of the key is stored.
  def self.create_with_api_key!(api_key: "pk_#{SecureRandom.hex(24)}", **attributes)
    merchant = create!(**attributes, api_key_digest: digest(api_key))
    [ merchant, api_key ]
  end

  def self.authenticate(api_key)
    return if api_key.blank?

    find_by(api_key_digest: digest(api_key))
  end

  def self.digest(api_key)
    OpenSSL::Digest::SHA256.hexdigest(api_key)
  end

  private

  def webhook_url_must_be_http
    return if webhook_url.blank?

    uri = URI.parse(webhook_url)
    errors.add(:webhook_url, "must be an http(s) URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:webhook_url, "must be an http(s) URL")
  end

  def generate_webhook_secret
    self.webhook_secret ||= "whsec_#{SecureRandom.hex(24)}"
  end
end
