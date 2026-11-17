require "rails_helper"

RSpec.describe CreateCharge, type: :service do
  let(:merchant) { create(:merchant) }
  let(:params) { { amount_cents: 2500, description: "Assinatura" } }

  def call(key: "abc-123", body: params)
    described_class.call(merchant:, idempotency_key: key, params: body)
  end

  it "creates a charge on the first request" do
    result = call
    aggregate_failures do
      expect(result).to be_success
      expect(result.created).to be true
      expect(result.charge).to be_persisted
    end
  end

  it "returns the same charge when the key is replayed with the same body" do
    first = call.charge
    expect { @second = call }.not_to change(Charge, :count)
    expect(@second.charge).to eq(first)
    expect(@second.created).to be false
  end

  it "rejects the same key with a different body" do
    call
    expect(call(body: params.merge(amount_cents: 9999)).error).to eq(:idempotency_conflict)
  end

  it "requires an idempotency key" do
    expect(call(key: " ").error).to eq(:missing_idempotency_key)
  end

  it "scopes keys per merchant" do
    call
    other = described_class.call(merchant: create(:merchant), idempotency_key: "abc-123", params:)
    expect(other.created).to be true
  end

  it "returns validation errors" do
    result = call(body: { amount_cents: 0 })
    expect(result.error).to eq(:invalid)
    expect(result.charge.errors[:amount_cents]).to be_present
  end

  it "recovers when a concurrent request wins the unique index" do
    winner = create(:charge, merchant:, idempotency_key: "abc-123",
                             request_fingerprint: OpenSSL::Digest::SHA256.hexdigest("2500|Assinatura"))
    allow(merchant.charges).to receive(:find_by).and_return(nil, winner)
    allow(merchant.charges).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

    expect(call.charge).to eq(winner)
  end
end
