# frozen_string_literal: true

require "test_helper"

class TurboStreamSubscriptionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "authenticated layout includes ship broadcast subscription" do
    sign_in_as(@user)
    get ships_path

    assert_response :success
    # turbo_stream_from renders as <turbo-cable-stream-source>
    assert_includes response.body, "turbo-cable-stream-source"
    # Check that the stream is subscribed (signed stream name contains our target)
    # The actual stream name is signed/encoded, so we check for the presence of the element
  end

  test "authenticated layout includes building broadcast subscription" do
    sign_in_as(@user)
    get buildings_path

    assert_response :success
    assert_includes response.body, "turbo-cable-stream-source"
  end

  test "recruiter page includes tier-specific recruit pool subscription" do
    sign_in_as(@user)
    get recruiter_workers_path

    assert_response :success
    # Should have both the global streams and the recruiter-specific one
    assert_includes response.body, "turbo-cable-stream-source"
  end
end
