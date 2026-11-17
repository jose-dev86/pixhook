# Builds a "Pix copia e cola" payload following the Central Bank BR Code (EMV MPM) layout,
# including the CRC16-CCITT checksum, so any banking app can parse the QR code.
# The receiver key is a demo key: paying it in a real app is not possible.
class PixBrCode
  GUI = "BR.GOV.BCB.PIX".freeze
  DEMO_KEY = "pixhook@exemplo.com".freeze
  MERCHANT_NAME = "PIXHOOK DEMO".freeze
  MERCHANT_CITY = "TERESINA".freeze

  def self.call(...) = new(...).call

  def initialize(amount_cents:, txid:, key: DEMO_KEY)
    @amount_cents = amount_cents
    @txid = txid.to_s.gsub(/[^A-Za-z0-9]/, "").first(25).presence || "***"
    @key = key
  end

  def call
    payload = [
      field("00", "01"),
      field("26", field("00", GUI) + field("01", @key)),
      field("52", "0000"),
      field("53", "986"),
      field("54", format("%.2f", @amount_cents / 100.0)),
      field("58", "BR"),
      field("59", MERCHANT_NAME),
      field("60", MERCHANT_CITY),
      field("62", field("05", @txid))
    ].join + "6304"

    payload + crc16(payload)
  end

  private

  def field(id, value)
    "#{id}#{value.length.to_s.rjust(2, '0')}#{value}"
  end

  # CRC16-CCITT (polynomial 0x1021, initial value 0xFFFF), as required by the BR Code spec.
  def crc16(data)
    crc = 0xFFFF
    data.each_byte do |byte|
      crc ^= byte << 8
      8.times { crc = crc.anybits?(0x8000) ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF }
    end
    crc.to_s(16).upcase.rjust(4, "0")
  end
end
