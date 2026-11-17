require "rails_helper"

RSpec.describe PixBrCode do
  subject(:code) { described_class.call(amount_cents: 4990, txid: "abc-123") }

  it "starts with the payload format indicator and Pix GUI" do
    expect(code).to start_with("000201").and include("0014BR.GOV.BCB.PIX")
  end

  it "encodes amount, currency, country and txid" do
    expect(code).to include("540549.90", "5303986", "5802BR", "62100506abc123")
  end

  it "ends with a valid CRC16 over the whole payload" do
    body, crc = code[0..-5], code[-4..]
    expect(described_class.new(amount_cents: 1, txid: "x").send(:crc16, body)).to eq(crc)
  end

  it "matches the known CRC for the standard check string" do
    expect(described_class.new(amount_cents: 1, txid: "x").send(:crc16, "123456789")).to eq("29B1")
  end

  it "truncates txid to 25 alphanumeric chars" do
    long = described_class.call(amount_cents: 100, txid: "a" * 40)
    expect(long).to include("0525#{'a' * 25}")
  end
end
