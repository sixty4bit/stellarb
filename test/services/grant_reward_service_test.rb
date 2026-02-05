# frozen_string_literal: true

require "test_helper"

class GrantRewardServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @initial_credits = @user.credits
  end

  test "award_credits! adds grant amount to user credits" do
    service = GrantRewardService.new(@user)
    service.award_credits!

    @user.reload
    expected = @initial_credits + GrantCalculator::GRANT_AMOUNT
    assert_equal expected, @user.credits
  end

  test "award_credits! returns the granted amount" do
    service = GrantRewardService.new(@user)
    result = service.award_credits!

    assert_equal GrantCalculator::GRANT_AMOUNT, result
  end

  test "award_credits! persists the change" do
    service = GrantRewardService.new(@user)
    service.award_credits!

    fresh_user = User.find(@user.id)
    expected = @initial_credits + GrantCalculator::GRANT_AMOUNT
    assert_equal expected, fresh_user.credits
  end

  test "award_credits! works when user has zero credits" do
    @user.update!(credits: 0)
    service = GrantRewardService.new(@user)
    service.award_credits!

    @user.reload
    assert_equal GrantCalculator::GRANT_AMOUNT, @user.credits
  end

  test "award_credits! adds to existing credits" do
    @user.update!(credits: 1_500)
    service = GrantRewardService.new(@user)
    service.award_credits!

    @user.reload
    assert_equal 1_500 + GrantCalculator::GRANT_AMOUNT, @user.credits
  end
end
