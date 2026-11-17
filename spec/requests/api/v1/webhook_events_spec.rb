require "swagger_helper"

RSpec.describe "API v1 Webhook events", type: :request do
  let(:api_key) { "pk_test_events" }
  let!(:merchant) { create(:merchant, api_key_digest: Merchant.digest(api_key)) }
  let(:Authorization) { "Bearer #{api_key}" }

  path "/api/v1/webhook_events" do
    get "Lista as entregas de webhook" do
      tags "Webhooks"
      security [ bearer: [] ]
      produces "application/json"

      response "200", "lista" do
        before { create(:webhook_event, merchant:) }
        run_test! { |response| expect(JSON.parse(response.body)["data"].size).to eq(1) }
      end
    end
  end

  path "/api/v1/webhook_events/{id}/redeliver" do
    parameter name: :id, in: :path, type: :integer

    post "Reenvia um webhook (inclusive da fila de mortos)" do
      tags "Webhooks"
      security [ bearer: [] ]
      produces "application/json"

      response "202", "reenfileirado" do
        let(:id) { create(:webhook_event, merchant:, status: :dead).id }
        run_test! do
          expect(WebhookEvent.find(id)).to be_pending
          expect(WebhookDeliveryJob.jobs.size).to be >= 1
        end
      end
    end
  end
end
