ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Code coverage
require "simplecov"
SimpleCov.start "rails" do
  # Enable coverage for parallel tests
  enable_coverage :branch
  primary_coverage :line

  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Channels", "app/channels"
end

# HTTP mocking
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)

# Mocha for mocking/stubbing
require "mocha/minitest"

# Shoulda matchers
require "shoulda/matchers"

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

module ActiveSupport
  class TestCase
    # Disable parallelization for accurate coverage reporting
    # parallelize(workers: :number_of_processors)

    # Disable fixtures - we create data programmatically
    # fixtures :all
    self.use_transactional_tests = true

    # Add more helper methods to be used by all tests here...

    # Helper to create a user for tests
    def create_test_user(attributes = {})
      User.create!(
        email_address: attributes[:email_address] || "test#{rand(10000)}@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: attributes[:first_name] || "Test",
        last_name: attributes[:last_name] || "User",
        email_verified_at: Time.current
      )
    end

    # Helper to sign in a user in controller tests
    def sign_in_as(user)
      post session_url, params: {
        email_address: user.email_address,
        password: "password123"
      }
    end
  end
end
