# frozen_string_literal: true

# Service for awarding The Grant reward to users who complete Phase 1 (The Cradle)
# Handles credit awards and related reward mechanics
class GrantRewardService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Award the grant credits to the user's account
  # @return [Integer] The amount of credits awarded
  def award_credits!
    grant_amount = GrantCalculator.calculate
    user.increment!(:credits, grant_amount)
    grant_amount
  end
end
