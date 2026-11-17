# Stripe-style signature: "t=<unix>,v1=<hex hmac-sha256 of "t.body">".
# Receivers reject signatures older than TOLERANCE to block replay attacks.
module WebhookSignature
  TOLERANCE = 5.minutes

  module_function

  def header(secret:, body:, timestamp: Time.current.to_i)
    "t=#{timestamp},v1=#{hmac(secret, timestamp, body)}"
  end

  def valid?(secret:, body:, header:, now: Time.current.to_i)
    parts = header.to_s.split(",").filter_map { |pair| pair.split("=", 2) if pair.include?("=") }.to_h
    timestamp = Integer(parts["t"], exception: false)
    return false if timestamp.nil? || parts["v1"].blank?
    return false if (now - timestamp).abs > TOLERANCE.to_i

    ActiveSupport::SecurityUtils.secure_compare(hmac(secret, timestamp, body), parts["v1"])
  end

  def hmac(secret, timestamp, body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
  end
end
