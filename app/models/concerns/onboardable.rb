# frozen_string_literal: true

# Onboarding state tracking for User model.
# Tracks a user's progress through the initial tutorial flow.
module Onboardable
  extend ActiveSupport::Concern

  ONBOARDING_STEPS = %w[
    profile_setup
    ships_tour
    navigation_tutorial
    trade_routes
    workers_overview
    inbox_introduction
  ].freeze

  included do
    # Enum for onboarding step - provides step-specific query methods
    enum :onboarding_step, {
      profile_setup: "profile_setup",
      ships_tour: "ships_tour",
      navigation_tutorial: "navigation_tutorial",
      trade_routes: "trade_routes",
      workers_overview: "workers_overview",
      inbox_introduction: "inbox_introduction"
    }, default: :profile_setup

    # Scope for users still in onboarding
    scope :onboarding, -> { where(onboarding_completed_at: nil) }
    scope :onboarding_complete, -> { where.not(onboarding_completed_at: nil) }
  end

  # Check if onboarding is complete
  # @return [Boolean]
  def onboarding_complete?
    onboarding_completed_at.present?
  end

  # Check if user needs onboarding
  # @return [Boolean]
  def needs_onboarding?
    !onboarding_complete?
  end

  # Get the current step as a symbol, or nil if complete
  # @return [Symbol, nil]
  def current_onboarding_step
    return nil if onboarding_complete?

    onboarding_step.to_sym
  end

  # Check if user is on a specific onboarding step
  # @param step [Symbol, String] The step to check
  # @return [Boolean]
  def on_onboarding_step?(step)
    return false if onboarding_complete?

    onboarding_step == step.to_s
  end

  # Advance to the next onboarding step
  # Does nothing if onboarding is already complete
  # Marks complete if advancing past the last step
  def advance_onboarding_step!
    return if onboarding_complete?

    current_step = onboarding_step
    current_index = ONBOARDING_STEPS.index(current_step)
    return if current_index.nil?

    next_index = current_index + 1

    if next_index >= ONBOARDING_STEPS.length
      # Completing the final step
      update!(onboarding_completed_at: Time.current)
    else
      update!(onboarding_step: ONBOARDING_STEPS[next_index])
    end

    # Trigger step-specific actions after advancement
    on_navigation_tutorial_complete! if current_step == "navigation_tutorial"
  end

  # Skip onboarding entirely
  # Marks onboarding as complete immediately
  def skip_onboarding!
    update!(onboarding_completed_at: Time.current)
  end

  # Reset onboarding to the beginning
  # Useful for testing or allowing users to replay the tutorial
  def reset_onboarding!
    update!(
      onboarding_step: ONBOARDING_STEPS.first,
      onboarding_completed_at: nil
    )
  end

  private

  NAVIGATION_TUTORIAL_REWARD = 500

  # Called when user completes navigation tutorial
  # Awards credits and creates an inbox message celebrating their progress
  def on_navigation_tutorial_complete!
    # Award credits
    update!(credits: credits + NAVIGATION_TUTORIAL_REWARD)

    # Create congratulatory inbox message
    messages.create!(
      title: "Navigation Training Complete!",
      from: "Navigation Academy",
      category: "achievement",
      body: <<~BODY.strip
        Congratulations, pilot!

        You've mastered the basics of stellar navigation. The galaxy is now truly open to you.

        🎉 REWARD: #{NAVIGATION_TUTORIAL_REWARD} credits have been added to your account!

        Your navigation skills allow you to:
        • Plot courses between star systems
        • Discover new locations and trade routes
        • Find the most profitable paths for your cargo

        Keep exploring - there's always more to discover among the stars!

        — The Navigation Academy
      BODY
    )
  end
end
