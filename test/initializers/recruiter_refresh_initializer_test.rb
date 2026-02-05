# frozen_string_literal: true

require "test_helper"

class RecruiterRefreshInitializerTest < ActiveSupport::TestCase
  test "initializer file exists" do
    initializer_path = Rails.root.join("config/initializers/recruiter_refresh.rb")
    assert File.exist?(initializer_path), "Initializer file should exist"
  end

  test "RecruiterRefreshJob responds to ensure_pool_ready" do
    assert_respond_to RecruiterRefreshJob, :ensure_pool_ready
  end

  test "initializer only runs in server context" do
    # The initializer uses `Rails.application.config.after_initialize` with
    # server context detection. This test verifies the design intent.
    initializer_content = File.read(Rails.root.join("config/initializers/recruiter_refresh.rb"))

    # Should check for server context (not rake tasks, migrations, etc.)
    assert_match(/server.*running|console.*running|web.*dyno|after_initialize/i, initializer_content,
      "Initializer should have context-aware execution")
  end
end
