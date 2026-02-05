# frozen_string_literal: true

# Controller for onboarding tutorial flow
# Handles advancing and skipping the onboarding steps
class OnboardingController < ApplicationController
  before_action :require_login

  # POST /onboarding/advance
  # Advance to the next onboarding step
  def advance
    current_user.advance_onboarding_step!
    redirect_to_step_target
  end

  # POST /onboarding/skip
  # Skip onboarding entirely
  def skip
    current_user.skip_onboarding!
    redirect_to inbox_path, notice: "Tutorial skipped. You can replay it anytime from settings."
  end

  # POST /onboarding/reset
  # Reset onboarding to beginning (for replaying tutorial)
  def reset
    current_user.reset_onboarding!
    redirect_to inbox_path, notice: "Tutorial reset. Welcome back!"
  end

  private

  def redirect_to_step_target
    if current_user.onboarding_complete?
      redirect_to inbox_path, notice: "Congratulations! You've completed the tutorial. Time to make some credits!"
      return
    end

    # Redirect based on current step to guide user to the right place
    case current_user.onboarding_step
    when "profile_setup"
      redirect_to inbox_path # Will show profile setup overlay
    when "ships_tour"
      redirect_to ships_path
    when "navigation_tutorial"
      redirect_to navigation_index_path
    when "trade_routes"
      redirect_to routes_path
    when "workers_overview"
      redirect_to workers_path
    else
      redirect_to inbox_path
    end
  end
end
