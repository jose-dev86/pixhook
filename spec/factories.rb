FactoryBot.define do
  factory :merchant do
    sequence(:name) { |n| "Loja #{n}" }
    sequence(:api_key_digest) { |n| Merchant.digest("pk_test_#{n}") }
    webhook_url { "https://merchant.example.com/webhooks" }
  end

  factory :charge do
    merchant
    amount_cents { 1990 }
    description { "Pedido #123" }
    sequence(:idempotency_key) { |n| "key-#{n}" }
    request_fingerprint { "fp" }
  end

  factory :webhook_event do
    merchant
    charge { association :charge, merchant: }
    event_type { "charge.paid" }
    payload { { event: "charge.paid", data: { id: 1 } } }
  end
end
