# frozen_string_literal: true

require "test_helper"

class MobileLoginOnboardingTest < ActionDispatch::IntegrationTest
  test "login page has responsive ASCII art" do
    get new_session_path
    assert_response :success
    # ASCII art should be hidden on very small screens, visible on sm+
    assert_select "pre.hidden.sm\\:block"
  end

  test "login form container is full width on mobile" do
    get new_session_path
    assert_response :success
    # Container should have responsive width classes
    assert_select "div.w-full"
  end

  test "profile edit fields are full width on mobile" do
    user = users(:one)
    sign_in_as(user)
    get edit_profile_path
    assert_response :success
    assert_select "input.w-full"
  end

  test "onboarding overlay has responsive classes" do
    user = users(:one)
    user.update!(onboarding_step: "profile_setup", onboarding_completed_at: nil)
    sign_in_as(user)
    get inbox_index_path
    assert_response :success
    # Sidebar should have responsive width: full on mobile, w-80 on sm+
    assert_select "#onboarding-sidebar.w-full.sm\\:w-80"
  end
end
