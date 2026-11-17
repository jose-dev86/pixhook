require "rails_helper"

RSpec.describe WebhookDeliveryJob, type: :job do
  let(:merchant) { create(:merchant, webhook_url: "https://merchant.example.com/hooks") }
  let(:event) { create(:webhook_event, merchant:) }

  def perform = described_class.new.perform(event.id)

  context "when the merchant answers 2xx" do
    before { stub_request(:post, merchant.webhook_url).to_return(status: 200) }

    it "marks the event delivered" do
      perform
      aggregate_failures do
        expect(event.reload).to be_delivered
        expect(event.attempts).to eq(1)
        expect(event.last_response_code).to eq(200)
      end
    end

    it "sends a verifiable signature" do
      perform
      expect(a_request(:post, merchant.webhook_url).with { |req|
        WebhookSignature.valid?(secret: merchant.webhook_secret, body: req.body, header: req.headers["X-Pixhook-Signature"])
      }).to have_been_made.once
    end

    it "is idempotent: an already delivered event is not sent again" do
      perform
      perform
      expect(a_request(:post, merchant.webhook_url)).to have_been_made.once
    end
  end

  context "when the merchant answers 5xx" do
    before { stub_request(:post, merchant.webhook_url).to_return(status: 503) }

    it "records the failure and raises so Sidekiq retries" do
      expect { perform }.to raise_error(described_class::DeliveryFailed, /503/)
      expect(event.reload).to have_attributes(status: "pending", attempts: 1, last_response_code: 503)
    end
  end

  context "when the connection times out" do
    before { stub_request(:post, merchant.webhook_url).to_timeout }

    it "raises and keeps the event pending" do
      expect { perform }.to raise_error(described_class::DeliveryFailed)
      expect(event.reload.last_error).to match(/Faraday/)
    end
  end

  context "when the merchant has no webhook_url" do
    let(:merchant) { create(:merchant, webhook_url: nil) }

    it "marks the event dead without HTTP calls" do
      perform
      expect(event.reload).to be_dead
    end
  end

  describe "retries exhausted" do
    it "moves the event to the dead letter state" do
      described_class.sidekiq_retries_exhausted_block.call({ "args" => [ event.id ] }, StandardError.new("boom"))
      expect(event.reload).to have_attributes(status: "dead", last_error: "boom")
    end
  end

  it "uses explicit HTTP timeouts" do
    request = described_class.new.send(:connection).options
    expect([ request.open_timeout, request.timeout ]).to eq([ 2, 5 ])
  end
end
