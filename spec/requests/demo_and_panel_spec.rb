require "rails_helper"

RSpec.describe "Demo receiver and panel", type: :request do
  let(:merchant) { create(:merchant) }
  let(:body) { { event: "charge.paid" }.to_json }

  describe "POST /demo/webhooks/:merchant_id" do
    it "accepts a valid signature" do
      signature = WebhookSignature.header(secret: merchant.webhook_secret, body:)
      post demo_webhook_receiver_path(merchant), params: body, headers: { "X-PixHook-Signature" => signature, "Content-Type" => "application/json" }
      expect(response).to have_http_status(:no_content)
    end

    it "rejects an invalid signature" do
      post demo_webhook_receiver_path(merchant), params: body, headers: { "X-PixHook-Signature" => "t=1,v1=bad", "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "panel" do
    it "lists the demo merchant charges" do
      charge = create(:charge, merchant:)
      get root_path
      expect(response.body).to include(charge.txid.first(10))
    end

    it "asks to seed when there is no merchant" do
      get root_path
      expect(response.body).to include("db:seed")
    end

    it "simulates a payment" do
      charge = create(:charge, merchant:)
      post pay_charge_path(charge)
      expect(charge.reload).to be_paid
    end

    it "shows an alert for an invalid transition" do
      charge = create(:charge, merchant:).tap(&:pay!)
      post pay_charge_path(charge)
      expect(flash[:alert]).to match(/paid/)
    end
  end
end
