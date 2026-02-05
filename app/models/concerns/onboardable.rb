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
  ].freeze

  included do
    # Enum for onboarding step - provides step-specific query methods
    enum :onboarding_step, {
      profile_setup: "profile_setup",
      ships_tour: "ships_tour",
      navigation_tutorial: "navigation_tutorial",
      trade_routes: "trade_routes",
      workers_overview: "workers_overview"
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

    current_index = ONBOARDING_STEPS.index(onboarding_step)
    return if current_index.nil?

    next_index = current_index + 1

    if next_index >= ONBOARDING_STEPS.length
      # Completing the final step
      update!(onboarding_completed_at: Time.current)
    else
      update!(onboarding_step: ONBOARDING_STEPS[next_index])
    end
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
end
