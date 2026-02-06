# frozen_string_literal: true

require "test_helper"

class RecruitCountdownTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "recruiter index includes countdown controller for pool refresh" do
    sign_in_as(@user)

    # Create a recruit available for this user's tier
    recruit = Recruit.generate!(level_tier: @user.level_tier)

    get recruiters_path
    assert_response :success

    # Should have countdown controller with arrival time for pool refresh
    assert_select "[data-controller='countdown']" do |elements|
      assert elements.any? { |el| el["data-countdown-arrival-value"].present? }
    end
  end

  test "recruiter show includes countdown controller for recruit expiration" do
    sign_in_as(@user)

    # Create a recruit available for this user's tier
    recruit = Recruit.generate!(level_tier: @user.level_tier)

    get recruiter_path(recruit)
    assert_response :success

    # Should have countdown controller with arrival time for expiration
    assert_select "[data-controller='countdown'][data-countdown-arrival-value='#{recruit.expires_at.iso8601}']"
  end

  test "recruiter index has no countdown when no recruits" do
    sign_in_as(@user)

    # Expire all recruits instead of destroying (avoids FK issues)
    Recruit.available_for(@user).update_all(expires_at: 1.day.ago)

    get recruiters_path
    assert_response :success

    # Should not have countdown controller (no @next_refresh)
    assert_select "[data-controller='countdown']", count: 0
  end
end
