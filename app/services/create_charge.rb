# Creates a charge honoring the Idempotency-Key header.
# Same key + same body returns the original charge; same key + different body is a conflict.
class CreateCharge
  Result = Data.define(:charge, :created, :error) do
    def success? = error.nil?
  end

  def self.call(...) = new(...).call

  def initialize(merchant:, idempotency_key:, params:)
    @merchant = merchant
    @idempotency_key = idempotency_key.to_s.strip
    @params = params
  end

  def call
    return failure(:missing_idempotency_key) if @idempotency_key.blank?

    existing = find_existing
    return replay(existing) if existing

    charge = @merchant.charges.create!(
      amount_cents: @params[:amount_cents],
      description: @params[:description],
      idempotency_key: @idempotency_key,
      request_fingerprint: fingerprint
    )
    Result.new(charge:, created: true, error: nil)
  rescue ActiveRecord::RecordNotUnique
    # Two concurrent requests with the same key: the unique index decides the winner.
    replay(find_existing)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(charge: e.record, created: false, error: :invalid)
  end

  private

  def find_existing
    @merchant.charges.find_by(idempotency_key: @idempotency_key)
  end

  def replay(charge)
    return failure(:idempotency_conflict) if charge.request_fingerprint != fingerprint

    Result.new(charge:, created: false, error: nil)
  end

  def fingerprint
    @fingerprint ||= OpenSSL::Digest::SHA256.hexdigest([ @params[:amount_cents].to_s, @params[:description].to_s ].join("|"))
  end

  def failure(error)
    Result.new(charge: nil, created: false, error:)
  end
end
