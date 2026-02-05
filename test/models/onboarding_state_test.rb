# frozen_string_literal: true

require "test_helper"

class OnboardingStateTest < ActiveSupport::TestCase
  def setup
    @system = System.create!(x: 0, y: 0, z: 0, name: "Test System")
    @user = User.create!(
      email: "onboarding@test.com",
      name: "OnboardUser"
    )
  end

  # ===========================================
  # Initial State
  # ===========================================

  test "new user starts with onboarding_step profile_setup" do
    assert_equal "profile_setup", @user.onboarding_step
  end

  test "new user has onboarding_complete? false" do
    assert_not @user.onboarding_complete?
  end

  test "new user needs_onboarding? is true" do
    assert @user.needs_onboarding?
  end

  # ===========================================
  # Step Progression
  # ===========================================

  test "ONBOARDING_STEPS constant defines correct order ending at inbox" do
    expected = %w[profile_setup ships_tour navigation_tutorial trade_routes workers_overview inbox_introduction]
    assert_equal expected, User::ONBOARDING_STEPS
  end

  test "advance_onboarding_step! moves to next step through all steps ending at inbox" do
    assert_equal "profile_setup", @user.onboarding_step

    @user.advance_onboarding_step!
    assert_equal "ships_tour", @user.onboarding_step

    @user.advance_onboarding_step!
    assert_equal "navigation_tutorial", @user.onboarding_step

    @user.advance_onboarding_step!
    assert_equal "trade_routes", @user.onboarding_step

    @user.advance_onboarding_step!
    assert_equal "workers_overview", @user.onboarding_step

    @user.advance_onboarding_step!
    assert_equal "inbox_introduction", @user.onboarding_step
  end

  test "inbox_introduction is the final step before completion" do
    @user.update!(onboarding_step: "inbox_introduction")
    assert_not @user.onboarding_complete?

    @user.advance_onboarding_step!
    assert @user.onboarding_complete?
  end

  test "advance_onboarding_step! completes onboarding on final step" do
    # Advance through all steps
    User::ONBOARDING_STEPS.length.times do
      @user.advance_onboarding_step!
    end

    assert @user.onboarding_complete?
    assert_not_nil @user.onboarding_completed_at
  end

  test "advance_onboarding_step! does nothing when already complete" do
    @user.update!(onboarding_completed_at: 1.day.ago)

    assert_no_changes -> { @user.onboarding_step } do
      @user.advance_onboarding_step!
    end
  end

  # ===========================================
  # Skip Onboarding
  # ===========================================

  test "skip_onboarding! marks onboarding as complete" do
    assert_not @user.onboarding_complete?

    @user.skip_onboarding!

    assert @user.onboarding_complete?
    assert_not_nil @user.onboarding_completed_at
  end

  # ===========================================
  # Current Step Helpers
  # ===========================================

  test "current_onboarding_step returns nil when complete" do
    @user.update!(onboarding_completed_at: Time.current)

    assert_nil @user.current_onboarding_step
  end

  test "current_onboarding_step returns step symbol when in progress" do
    assert_equal :profile_setup, @user.current_onboarding_step
  end

  test "on_onboarding_step? returns true for current step" do
    assert @user.on_onboarding_step?(:profile_setup)
    assert_not @user.on_onboarding_step?(:ships_tour)
  end

  # ===========================================
  # Step-specific Queries
  # ===========================================

  test "enum helpers work for onboarding_step" do
    assert @user.profile_setup?

    @user.update!(onboarding_step: "ships_tour")
    assert @user.ships_tour?

    @user.update!(onboarding_step: "trade_routes")
    assert @user.trade_routes?
  end

  # ===========================================
  # Reset Onboarding
  # ===========================================

  test "reset_onboarding! returns user to first step" do
    @user.skip_onboarding!
    assert @user.onboarding_complete?

    @user.reset_onboarding!

    assert_not @user.onboarding_complete?
    assert_equal "profile_setup", @user.onboarding_step
    assert_nil @user.onboarding_completed_at
  end
end
