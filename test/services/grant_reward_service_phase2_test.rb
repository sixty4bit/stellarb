# frozen_string_literal: true

require "test_helper"

class GrantRewardServicePhase2Test < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(tutorial_phase: "cradle")
  end

  test "unlock_phase2! advances user from cradle to proving_ground" do
    service = GrantRewardService.new(@user)
    service.unlock_phase2!

    @user.reload
    assert_equal "proving_ground", @user.tutorial_phase
  end

  test "unlock_phase2! returns true on success" do
    service = GrantRewardService.new(@user)
    result = service.unlock_phase2!

    assert result
  end

  test "unlock_phase2! is idempotent - calling twice doesn't advance further" do
    service = GrantRewardService.new(@user)
    service.unlock_phase2!
    service.unlock_phase2!

    @user.reload
    assert_equal "proving_ground", @user.tutorial_phase
  end

  test "award! orchestrates all grant rewards" do
    service = GrantRewardService.new(@user)
    initial_credits = @user.credits

    result = service.award!

    @user.reload
    # Credits awarded
    assert_equal initial_credits + GrantCalculator::GRANT_AMOUNT, @user.credits
    # Phase unlocked
    assert_equal "proving_ground", @user.tutorial_phase
    # Notification sent
    assert @user.messages.exists?(category: "reward")
    # Returns success
    assert result[:success]
  end

  test "award! returns breakdown of what was done" do
    service = GrantRewardService.new(@user)
    result = service.award!

    assert result[:success]
    assert_equal GrantCalculator::GRANT_AMOUNT, result[:credits_awarded]
    assert_equal "proving_ground", result[:new_phase]
    assert_not_nil result[:message]
  end

  test "award! only works for users in cradle phase" do
    @user.update!(tutorial_phase: "proving_ground")
    service = GrantRewardService.new(@user)

    result = service.award!

    assert_not result[:success]
    assert_includes result[:error], "cradle"
  end
end
