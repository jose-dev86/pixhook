# End-to-end tests: Capybara + Playwright (headless Chromium).
# The app runs in a real Puma server; webhooks are delivered over HTTP to the app's own
# signed receiver, and Turbo Streams reach the browser through Action Cable.
require "capybara/rspec"
require "capybara/playwright"

SYSTEM_SERVER_PORT = 3101

common_options = {
  browser_type: :chromium,
  headless: ENV.fetch("HEADLESS", "true") != "false",
  playwright_cli_executable_path: "npx playwright",
  locale: "pt-BR",
  timezoneId: "America/Sao_Paulo",
  permissions: %w[clipboard-read clipboard-write]
}

Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(app, **common_options, viewport: { width: 1366, height: 900 })
end

Capybara.register_driver(:playwright_mobile) do |app|
  Capybara::Playwright::Driver.new(app, **common_options, viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true)
end

Capybara.server = :puma, { Silent: true, Threads: "2:4" }
Capybara.server_host = "127.0.0.1"
Capybara.server_port = SYSTEM_SERVER_PORT
Capybara.default_max_wait_time = 5

module SystemHelpers
  def demo_merchant!
    merchant, = Merchant.create_with_api_key!(name: "Loja Demo")
    merchant.update!(webhook_url: "http://#{Capybara.server_host}:#{SYSTEM_SERVER_PORT}/demo/webhooks/#{merchant.id}")
    merchant
  end

  def clipboard_text
    page.driver.with_playwright_page do |playwright_page|
      origin = "http://#{Capybara.server_host}:#{SYSTEM_SERVER_PORT}"
      playwright_page.context.grant_permissions(%w[clipboard-read clipboard-write], origin:)
      playwright_page.evaluate("navigator.clipboard.readText()")
    end
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(:each, type: :system) do |example|
    driven_by(example.metadata[:mobile] ? :playwright_mobile : :playwright)
    WebMock.allow_net_connect!
    @previous_job_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline # Turbo broadcasts render immediately
    Sidekiq::Testing.inline!                # webhook delivery really happens
  end

  config.after(:each, type: :system) do
    # System specs run without a wrapping transaction (the browser, Puma and webhook
    # deliveries use their own DB connections), so tables are cleaned explicitly.
    ActiveRecord::Base.connection.truncate_tables(*%w[webhook_events charges merchants])
    ActiveJob::Base.queue_adapter = @previous_job_adapter
    Sidekiq::Testing.fake!
    WebMock.disable_net_connect!
  end
end
