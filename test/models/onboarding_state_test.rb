# frozen_string_literal: true

require "test_helper"

class OnboardingStateTest < ActiveSupport::TestCase
  def setup
    @system = System.find_or_create_by!(x: 0, y: 0, z: 0) { |s| s.name = "Origin" }
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

  # ===========================================
  # Navigation Tutorial Completion Message
  # ===========================================

  test "completing navigation tutorial creates inbox message" do
    @user.update!(onboarding_step: "navigation_tutorial")
    initial_message_count = @user.messages.count

    @user.advance_onboarding_step!

    assert_equal initial_message_count + 1, @user.messages.count
    message = @user.messages.last
    assert_equal "Navigation Training Complete!", message.title
    assert_equal "Navigation Academy", message.from
    assert_equal "achievement", message.category
    assert_match /navigation/i, message.body
  end

  test "navigation completion message is not created for other step advances" do
    @user.update!(onboarding_step: "ships_tour")
    initial_message_count = @user.messages.count

    @user.advance_onboarding_step!

    # No new navigation message should be created
    new_messages = @user.messages.where(title: "Navigation Training Complete!")
    assert_equal 0, new_messages.count
  end

  # ===========================================
  # Navigation Tutorial Credit Reward
  # ===========================================

  test "completing navigation tutorial awards 500 credits" do
    @user.update!(onboarding_step: "navigation_tutorial", credits: 1000)

    @user.advance_onboarding_step!

    @user.reload
    assert_equal 1500, @user.credits
  end

  test "navigation credit reward is not given for other step advances" do
    @user.update!(onboarding_step: "ships_tour", credits: 1000)

    @user.advance_onboarding_step!

    @user.reload
    assert_equal 1000, @user.credits
  end

  test "navigation completion message mentions the credit reward" do
    @user.update!(onboarding_step: "navigation_tutorial")

    @user.advance_onboarding_step!

    message = @user.messages.find_by(title: "Navigation Training Complete!")
    assert_match /500 credits/i, message.body
  end
end
