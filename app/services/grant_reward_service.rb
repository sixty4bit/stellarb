# frozen_string_literal: true

# Service for awarding The Grant reward to users who complete Phase 1 (The Cradle)
# Handles credit awards and related reward mechanics
class GrantRewardService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Full grant award orchestration - credits, notification, and phase unlock
  # Only works for users in the cradle phase
  # @return [Hash] Result with :success, :credits_awarded, :new_phase, :message, or :error
  def award!
    unless user.cradle?
      return {
        success: false,
        error: "Grant can only be awarded to users in the cradle phase"
      }
    end

    credits = award_credits!
    message = send_notification!
    unlock_phase2!

    {
      success: true,
      credits_awarded: credits,
      new_phase: user.tutorial_phase,
      message: message
    }
  end

  # Award the grant credits to the user's account
  # @return [Integer] The amount of credits awarded
  def award_credits!
    grant_amount = GrantCalculator.calculate
    user.increment!(:credits, grant_amount)
    grant_amount
  end

  # Send congratulations notification to user inbox
  # @return [Message] The created message
  def send_notification!
    grant_amount = GrantCalculator.calculate
    breakdown = GrantCalculator.breakdown

    user.messages.create!(
      title: "Congratulations! The Grant Has Been Awarded",
      from: "Colonial Authority",
      urgent: true,
      category: "reward",
      body: notification_body(grant_amount, breakdown)
    )
  end

  # Unlock Phase 2 (The Proving Ground) for the user
  # Advances from cradle to proving_ground. Idempotent.
  # @return [Boolean] true if successful
  def unlock_phase2!
    return true unless user.cradle?

    user.advance_tutorial_phase!
    true
  end

  private

  def notification_body(grant_amount, breakdown)
    <<~BODY
      Pilot #{user.name},

      The Colonial Authority is pleased to confirm your successful completion of Phase 1 training in The Cradle. Your demonstrated competence in establishing automated supply chains has earned you The Grant.

      **CREDITS AWARDED: #{number_with_delimiter(grant_amount)}**

      This funding is intended to support your transition to Phase 2: The Proving Ground.

      Recommended allocation:
      • Exploration Ship: ~#{number_with_delimiter(breakdown[:ship_cost])} credits
      • Crew Hiring: ~#{number_with_delimiter(breakdown[:crew_cost])} credits
      • Operating Capital: ~#{number_with_delimiter(breakdown[:operating_capital])} credits

      Your next objective: Purchase an exploration-class vessel and recruit a capable crew. Then proceed to the Talos Arm to begin your proving trials.

      Phase 2 is now unlocked.

      May the stars guide your path,
      Colonial Authority
    BODY
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
