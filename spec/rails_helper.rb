require "simplecov"
SimpleCov.start "rails" do
  next if ENV["COVERAGE"] == "false"

  enable_coverage :branch
  add_filter %w[/spec/ /config/ /db/]
  minimum_coverage line: 90
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"
require "sidekiq/testing"

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }

Sidekiq::Testing.fake!
WebMock.disable_net_connect!(allow_localhost: false)

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.before { Sidekiq::Worker.clear_all }
end
