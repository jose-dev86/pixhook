# Demo merchant whose webhooks are delivered to the app's own signed receiver.
# DEMO_API_KEY makes the public demo key predictable; without it a random key is printed once.
base_url = ENV.fetch("APP_URL", "http://localhost:3000")

if Merchant.none?
  options = { name: "Loja Demo" }
  options[:api_key] = ENV["DEMO_API_KEY"] if ENV["DEMO_API_KEY"].present?
  merchant, api_key = Merchant.create_with_api_key!(**options)
  puts "Lojista: #{merchant.name}"
  puts "API key: #{api_key}" if ENV["DEMO_API_KEY"].blank?
end

# Runs on every deploy so a changed APP_URL re-points the demo webhook.
demo = Merchant.find_by!(name: "Loja Demo")
demo.update!(webhook_url: "#{base_url}/demo/webhooks/#{demo.id}")
