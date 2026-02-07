# frozen_string_literal: true

require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  def setup
    @system = systems(:cradle)
    @user = User.create!(
      email: "onboarding@test.com",
      name: "OnboardUser",
      profile_completed_at: 1.day.ago,
      onboarding_step: "profile_setup"
    )
    sign_in_as(@user)
  end

  # ===========================================
  # Profile Setup Step (Step 1)
  # ===========================================

  test "new user starts on profile_setup step" do
    assert_equal "profile_setup", @user.onboarding_step
    assert @user.needs_onboarding?
  end

  test "advance from profile_setup goes to ships_tour" do
    assert_equal "profile_setup", @user.onboarding_step

    post advance_onboarding_path

    @user.reload
    assert_equal "ships_tour", @user.onboarding_step
    assert_redirected_to ships_path
  end

  # ===========================================
  # Advance Through All Steps
  # ===========================================

  test "advance through all steps completes onboarding" do
    steps_and_redirects = [
      ["profile_setup", ships_path],           # After advancing from profile_setup
      ["ships_tour", navigation_index_path],   # After advancing from ships_tour
      ["navigation_tutorial", routes_path],    # After advancing from navigation_tutorial
      ["trade_routes", workers_path],          # After advancing from trade_routes
      ["workers_overview", inbox_index_path],  # After advancing from workers_overview
      ["inbox_introduction", inbox_index_path] # After advancing from inbox_introduction (complete!)
    ]

    steps_and_redirects.each do |current_step, expected_redirect|
      assert_equal current_step, @user.reload.onboarding_step

      post advance_onboarding_path

      if current_step == "inbox_introduction"
        # Final step - should complete onboarding
        assert @user.reload.onboarding_complete?
      end

      assert_redirected_to expected_redirect
    end
  end

  # ===========================================
  # Skip Onboarding
  # ===========================================

  test "skip_onboarding marks onboarding complete" do
    assert @user.needs_onboarding?

    post skip_onboarding_path

    @user.reload
    assert @user.onboarding_complete?
    assert_redirected_to inbox_index_path
  end

  test "skip_onboarding shows appropriate flash message" do
    post skip_onboarding_path

    assert_equal "Tutorial skipped. You can replay it anytime from settings.", flash[:notice]
  end

  # ===========================================
  # Reset Onboarding
  # ===========================================

  test "reset_onboarding restarts tutorial" do
    @user.skip_onboarding!
    assert @user.onboarding_complete?

    post reset_onboarding_path

    @user.reload
    assert_not @user.onboarding_complete?
    assert_equal "hamburger_intro", @user.onboarding_step
    assert_redirected_to inbox_index_path
  end

  # ===========================================
  # Overlay Rendering
  # ===========================================

  test "overlay renders for user in onboarding" do
    get inbox_index_path

    assert_response :success
    assert_select "#onboarding-sidebar"
    assert_select "[data-controller='onboarding']"
  end

  test "overlay does not render for completed user" do
    @user.skip_onboarding!

    get inbox_index_path

    assert_response :success
    assert_select "#onboarding-sidebar", count: 0
  end

  # ===========================================
  # stellarb-77l.3: Pre-tutorial hamburger intro step
  # ===========================================

  test "new user starts on hamburger_intro step" do
    user = User.create!(
      email: "fresh@test.com",
      name: "FreshUser",
      profile_completed_at: 1.day.ago
    )
    assert_equal "hamburger_intro", user.onboarding_step
  end

  test "hamburger intro overlay has mobile-only class" do
    user = User.create!(
      email: "mobile@test.com",
      name: "MobileUser",
      profile_completed_at: 1.day.ago
    )
    sign_in_as(user)

    get inbox_index_path
    assert_response :success
    assert_select "#onboarding-sidebar" do |el|
      assert_includes el.first["class"], "sm:hidden"
    end
  end

  test "advance from hamburger_intro goes to profile_setup" do
    user = User.create!(
      email: "burger@test.com",
      name: "BurgerUser",
      profile_completed_at: 1.day.ago
    )
    sign_in_as(user)
    assert_equal "hamburger_intro", user.onboarding_step

    post advance_onboarding_path
    user.reload
    assert_equal "profile_setup", user.onboarding_step
  end

  # ===========================================
  # stellarb-77l.2: Tutorial overlay positioned at bottom on mobile
  # ===========================================

  test "onboarding overlay uses bottom positioning for mobile" do
    get inbox_index_path

    assert_response :success
    assert_select "#onboarding-sidebar" do |el|
      classes = el.first["class"]
      assert_includes classes, "bottom-0", "Should position at bottom for mobile"
      assert_includes classes, "sm:top-0", "Should position at top for desktop"
    end
  end

  # ===========================================
  # stellarb-77l.1: Welcome notification should not repeat
  # ===========================================

  test "user in onboarding without profile completed is not redirected to profile" do
    # User still in onboarding, profile NOT completed
    user = User.create!(
      email: "newbie@test.com",
      name: "Newbie",
      profile_completed_at: nil
    )
    sign_in_as(user)

    assert user.needs_onboarding?
    assert_not user.profile_completed?

    # Advance past hamburger_intro to profile_setup
    post advance_onboarding_path
    user.reload
    assert_equal "profile_setup", user.onboarding_step

    # Advance past profile_setup to ships_tour
    post advance_onboarding_path
    user.reload
    assert_equal "ships_tour", user.onboarding_step

    # Visiting ships page should NOT redirect to profile with welcome notice
    get ships_path
    assert_response :success
    assert_nil flash[:notice]
  end

end
