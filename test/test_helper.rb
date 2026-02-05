# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Load all support files
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include bot simulation helper for all tests
    include BotSimulationHelper

    # Add more helper methods to be used by all tests here...
  end
end

# Helper for signing in during integration tests
module SignInHelper
  def sign_in_as(user)
    post sessions_path, params: { user: { email: user.email } }
    follow_redirect!
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end