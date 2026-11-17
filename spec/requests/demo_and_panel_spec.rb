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

  context "without a demo merchant" do
    it "asks to seed on the dashboard" do
      get root_path
      expect(response.body).to include("db:seed")
    end

    it "redirects panel pages to the dashboard" do
      get charges_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "with a demo merchant" do
    before { merchant }

    describe "dashboard" do
      it "shows KPIs in reais and the failed deliveries queue" do
        create(:charge, merchant:, amount_cents: 4990).pay!
        create(:webhook_event, merchant:, status: :dead, last_error: "HTTP 500")
        get root_path
        aggregate_failures do
          expect(response.body).to include("R$ 49,90", "Webhooks com falha", "HTTP 500")
          expect(response.body).to include("Reenviar")
        end
      end
    end

    describe "charges" do
      let!(:pending) { create(:charge, merchant:, description: "Camiseta") }
      let!(:paid) { create(:charge, merchant:, description: "Tênis").tap(&:pay!) }

      it "lists charges with translated statuses" do
        get charges_path
        expect(response.body).to include("Camiseta", "Tênis", "Pendente", "Paga")
      end

      it "filters by status" do
        get charges_path(status: "paid")
        expect(response.body).to include("Tênis")
        expect(response.body).not_to include("Camiseta")
      end

      it "ignores unknown status filters" do
        get charges_path(status: "hacked")
        expect(response.body).to include("Camiseta", "Tênis")
      end

      it "shows the detail with Pix QR code and timeline" do
        get charge_path(paid)
        aggregate_failures do
          expect(response.body).to include("<svg", "Pix copia e cola", paid.pix_copy_paste)
          expect(response.body).to include("Cobrança paga", "Linha do tempo")
        end
      end

      it "does not show charges from other merchants" do
        get charge_path(create(:charge))
        expect(response).to have_http_status(:not_found)
      end

      it "renders the new form with an idempotency key" do
        get new_charge_path
        expect(response.body).to match(/name="idempotency_key" [^>]*value="[0-9a-f-]{36}"/)
      end

      it "creates a charge from a value in reais" do
        expect {
          post charges_path, params: { idempotency_key: "form-1", charge: { amount: "1.234,56", description: "Notebook" } }
        }.to change(Charge, :count).by(1)
        expect(Charge.last).to have_attributes(amount_cents: 123_456, description: "Notebook")
        follow_redirect!
        expect(response.body).to include("Cobrança criada")
      end

      it "accepts a dot as decimal separator" do
        post charges_path, params: { idempotency_key: "form-2", charge: { amount: "49.90" } }
        expect(Charge.last.amount_cents).to eq(4990)
      end

      it "does not duplicate on double submit" do
        2.times { post charges_path, params: { idempotency_key: "form-3", charge: { amount: "10,00" } } }
        expect(Charge.where(idempotency_key: "form-3").count).to eq(1)
        follow_redirect!
        expect(response.body).to include("nada foi duplicado")
      end

      it "re-renders the form with errors for an invalid amount" do
        post charges_path, params: { idempotency_key: "form-4", charge: { amount: "abc" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Valor")
      end

      it "simulates a payment" do
        post pay_charge_path(pending)
        expect(pending.reload).to be_paid
      end

      it "refunds a paid charge" do
        post refund_charge_path(paid)
        expect(paid.reload).to be_refunded
      end

      it "explains an invalid transition in Portuguese" do
        post pay_charge_path(paid)
        expect(flash[:alert]).to eq("Não é possível fazer isso com uma cobrança paga.")
      end
    end

    describe "webhook events" do
      let!(:event) { create(:webhook_event, merchant:, status: :dead) }

      it "lists events with translated labels" do
        get webhook_events_path
        expect(response.body).to include("Cobrança paga", "Falhou")
      end

      it "redelivers an event" do
        post redeliver_webhook_event_path(event)
        aggregate_failures do
          expect(event.reload).to be_pending
          expect(WebhookDeliveryJob.jobs.size).to be >= 1
        end
      end
    end
  end
end
