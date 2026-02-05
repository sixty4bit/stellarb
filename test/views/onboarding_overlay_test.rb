# frozen_string_literal: true

require "test_helper"

class OnboardingOverlayTest < ActionView::TestCase
  include OnboardingHelper

  def setup
    @system = System.create!(x: 0, y: 0, z: 0, name: "Test System")
    @user = User.create!(
      email: "overlay@test.com",
      name: "OverlayUser"
    )

    # Setup route helpers for view rendering
    @routes = Rails.application.routes
  end

  # ===========================================
  # Helper Method Tests
  # ===========================================

  test "onboarding_step_config returns config for each step" do
    User::ONBOARDING_STEPS.each do |step|
      config = onboarding_step_config(step)
      assert config[:title].present?, "Step #{step} should have a title"
      assert config[:description].present?, "Step #{step} should have a description"
      assert config[:highlight].present?, "Step #{step} should have a highlight target"
      assert config[:icon].present?, "Step #{step} should have an icon"
    end
  end

  test "onboarding_step_config returns correct title for profile_setup" do
    config = onboarding_step_config("profile_setup")
    assert_equal "Welcome to StellArb!", config[:title]
  end

  test "onboarding_step_config returns correct title for trade_routes" do
    config = onboarding_step_config("trade_routes")
    assert_includes config[:title].downcase, "trade"
  end

  test "onboarding_progress returns current step index and total" do
    @user.update!(onboarding_step: "navigation_tutorial")
    progress = onboarding_progress(@user)

    assert_equal 3, progress[:current]  # 1-indexed: profile_setup=1, ships_tour=2, navigation_tutorial=3
    assert_equal 6, progress[:total]
  end

  test "onboarding_progress_percentage returns correct percentage" do
    @user.update!(onboarding_step: "trade_routes")  # Step 4 of 6
    percentage = onboarding_progress_percentage(@user)

    assert_equal 67, percentage  # 4/6 * 100 rounded
  end

  # ===========================================
  # Partial Rendering Tests
  # ===========================================

  test "onboarding_overlay partial renders when user needs onboarding" do
    html = render partial: "shared/onboarding_overlay", locals: { user: @user }

    assert_includes html, "data-controller=\"onboarding\""
    assert_includes html, @user.onboarding_step
  end

  test "onboarding_overlay partial includes skip button" do
    html = render partial: "shared/onboarding_overlay", locals: { user: @user }

    assert_includes html, "Skip"
  end

  test "onboarding_overlay partial includes continue button" do
    html = render partial: "shared/onboarding_overlay", locals: { user: @user }

    assert_includes html, "Continue" # or "Got it" or similar
  end

  test "onboarding_overlay partial shows progress indicator" do
    @user.update!(onboarding_step: "ships_tour")
    html = render partial: "shared/onboarding_overlay", locals: { user: @user }

    # Should show step 2 of 6
    assert_match(/2.*6|step 2/i, html)
  end
end
