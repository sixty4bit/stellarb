# frozen_string_literal: true

require "test_helper"

class OnboardingDesktopSkipTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(onboarding_step: "hamburger_intro", onboarding_completed_at: nil, profile_completed_at: Time.current)
    sign_in_as(@user)
  end

  test "hamburger_intro step renders mobile_only data attribute" do
    get inbox_index_path
    assert_response :success
    assert_select "[data-onboarding-mobile-only-value='true']"
  end

  test "profile_setup step does not have mobile_only attribute set to true" do
    @user.update!(onboarding_step: "profile_setup")
    get inbox_index_path
    assert_response :success
    assert_select "[data-onboarding-mobile-only-value='false']"
  end

  test "advance from hamburger_intro goes to profile_setup" do
    post advance_onboarding_path
    @user.reload
    assert_equal "profile_setup", @user.onboarding_step
  end
end
