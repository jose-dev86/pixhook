require "swagger_helper"

RSpec.describe "API v1 Charges", type: :request do
  let(:api_key) { "pk_test_request" }
  let!(:merchant) { create(:merchant, api_key_digest: Merchant.digest(api_key)) }
  let(:Authorization) { "Bearer #{api_key}" }

  charge_schema = {
    type: :object,
    properties: {
      id: { type: :integer }, txid: { type: :string },
      status: { type: :string, enum: %w[pending paid expired refunded] },
      amount_cents: { type: :integer }, description: { type: :string, nullable: true },
      pix_copy_paste: { type: :string }, expires_at: { type: :string, format: "date-time" },
      paid_at: { type: :string, nullable: true }, refunded_at: { type: :string, nullable: true },
      created_at: { type: :string, format: "date-time" }
    },
    required: %w[id txid status amount_cents expires_at]
  }

  path "/api/v1/charges" do
    post "Cria uma cobrança Pix (idempotente)" do
      tags "Charges"
      security [ bearer: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: "Idempotency-Key", in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { charge: { type: :object, properties: { amount_cents: { type: :integer }, description: { type: :string } }, required: %w[amount_cents] } },
        required: %w[charge]
      }

      let(:"Idempotency-Key") { "order-42" }
      let(:body) { { charge: { amount_cents: 4990, description: "Pedido 42" } } }

      response "201", "cobrança criada" do
        schema charge_schema
        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("pending")
          expect(response.headers["Idempotent-Replayed"]).to eq("false")
        end
      end

      response "200", "mesma chave e mesmo corpo devolvem a cobrança original" do
        before { post "/api/v1/charges", params: body.to_json, headers: { "Authorization" => send(:Authorization), "Idempotency-Key" => "order-42", "Content-Type" => "application/json" } }

        run_test! do |response|
          expect(Charge.count).to eq(1)
          expect(response.headers["Idempotent-Replayed"]).to eq("true")
        end
      end

      response "409", "mesma chave com corpo diferente" do
        before { create(:charge, merchant:, idempotency_key: "order-42", request_fingerprint: "other") }
        run_test!
      end

      response "400", "sem Idempotency-Key" do
        let(:"Idempotency-Key") { "" }
        run_test!
      end

      response "422", "valor inválido" do
        let(:body) { { charge: { amount_cents: 0 } } }
        run_test!
      end

      response "401", "API key inválida" do
        let(:Authorization) { "Bearer wrong" }
        run_test!
      end
    end

    get "Lista as cobranças do lojista" do
      tags "Charges"
      security [ bearer: [] ]
      produces "application/json"
      parameter name: :before_id, in: :query, type: :integer, required: false

      response "200", "lista paginada por cursor" do
        before { create_list(:charge, 3, merchant:) && create(:charge) }

        run_test! do |response|
          expect(JSON.parse(response.body)["data"].size).to eq(3)
        end
      end
    end
  end

  path "/api/v1/charges/{txid}" do
    parameter name: :txid, in: :path, type: :string

    get "Consulta uma cobrança" do
      tags "Charges"
      security [ bearer: [] ]
      produces "application/json"

      response "200", "encontrada" do
        schema charge_schema
        let(:txid) { create(:charge, merchant:).txid }
        run_test!
      end

      response "404", "de outro lojista" do
        let(:txid) { create(:charge).txid }
        run_test!
      end
    end
  end

  path "/api/v1/charges/{txid}/pay" do
    parameter name: :txid, in: :path, type: :string

    post "Simula o pagamento (dispara webhook charge.paid)" do
      tags "Charges"
      security [ bearer: [] ]
      produces "application/json"

      response "200", "paga" do
        let(:txid) { create(:charge, merchant:).txid }
        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("paid")
          expect(WebhookDeliveryJob.jobs.size).to eq(1)
        end
      end

      response "422", "transição inválida" do
        let(:txid) { create(:charge, merchant:).tap(&:pay!).txid }
        run_test!
      end
    end
  end

  path "/api/v1/charges/{txid}/refund" do
    parameter name: :txid, in: :path, type: :string

    post "Estorna uma cobrança paga" do
      tags "Charges"
      security [ bearer: [] ]
      produces "application/json"

      response "200", "estornada" do
        let(:txid) { create(:charge, merchant:).tap(&:pay!).txid }
        run_test!
      end
    end
  end
end
