require "rails_helper"

RSpec.describe Merchant, type: :model do
  it { is_expected.to validate_presence_of(:name) }

  describe ".create_with_api_key!" do
    it "stores only the digest and authenticates with the plain key" do
      merchant, api_key = described_class.create_with_api_key!(name: "Loja")
      aggregate_failures do
        expect(merchant.api_key_digest).not_to eq(api_key)
        expect(described_class.authenticate(api_key)).to eq(merchant)
        expect(merchant.webhook_secret).to start_with("whsec_")
      end
    end
  end

  describe ".authenticate" do
    it "returns nil for blank or unknown keys" do
      expect([ described_class.authenticate(""), described_class.authenticate("nope") ]).to all(be_nil)
    end
  end

  it "rejects webhook urls without http(s)" do
    merchant = build(:merchant, webhook_url: "ftp://x")
    expect(merchant).not_to be_valid
  end

  it "rejects malformed webhook urls" do
    expect(build(:merchant, webhook_url: "http://exa mple.com")).not_to be_valid
  end

  it "accepts a custom api key" do
    merchant, api_key = described_class.create_with_api_key!(name: "Demo", api_key: "pk_demo")
    expect([ api_key, described_class.authenticate("pk_demo") ]).to eq([ "pk_demo", merchant ])
  end
end
