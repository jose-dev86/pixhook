require "rails_helper"

RSpec.describe WebhookSignature do
  let(:secret) { "whsec_test" }
  let(:body) { { event: "charge.paid" }.to_json }

  it "accepts a fresh, correct signature" do
    header = described_class.header(secret:, body:)
    expect(described_class.valid?(secret:, body:, header:)).to be true
  end

  it "rejects a tampered body" do
    header = described_class.header(secret:, body:)
    expect(described_class.valid?(secret:, body: body.sub("paid", "refunded"), header:)).to be false
  end

  it "rejects the wrong secret" do
    header = described_class.header(secret: "other", body:)
    expect(described_class.valid?(secret:, body:, header:)).to be false
  end

  it "rejects replayed signatures older than the tolerance" do
    header = described_class.header(secret:, body:, timestamp: 10.minutes.ago.to_i)
    expect(described_class.valid?(secret:, body:, header:)).to be false
  end

  it "rejects malformed headers" do
    expect(described_class.valid?(secret:, body:, header: "garbage")).to be false
  end
end
