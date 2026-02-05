# frozen_string_literal: true

# Helper methods for onboarding overlay component
module OnboardingHelper
  STEP_CONFIGS = {
    "profile_setup" => {
      title: "Welcome to StellArb!",
      description: "Let's get you set up. First, we'll customize your profile and get you familiar with the interface.",
      highlight: "[data-menu-item='profile']",
      icon: "👤",
      action_text: "Set Up Profile"
    },
    "ships_tour" => {
      title: "Your Fleet Awaits",
      description: "Every captain needs ships. For your first vessel, we recommend the Myrmidon Scout — it's the cheapest ship (Myrmidon manufacturing is efficient!) and perfect for learning the ropes.",
      highlight: "[data-menu-item='ships']",
      icon: "🚀",
      action_text: "View Ships"
    },
    "navigation_tutorial" => {
      title: "Charting the Stars",
      description: "The galaxy is vast. Learn how to navigate between systems, discover new locations, and plan efficient routes.",
      highlight: "[data-menu-item='navigation']",
      icon: "🗺️",
      action_text: "Explore Navigation"
    },
    "trade_routes" => {
      title: "Trade Routes: Your Path to Profit",
      description: "Once you've done manual trades, automate them! Set up trade routes to earn credits while you're away. A profitable route is your first milestone!",
      highlight: "[data-menu-item='routes']",
      icon: "💰",
      action_text: "Create Trade Route"
    },
    "workers_overview" => {
      title: "Your Crew",
      description: "Hire NPCs to help run your empire. Workers can pilot ships, manage buildings, and keep things running smoothly.",
      highlight: "[data-menu-item='workers']",
      icon: "👥",
      action_text: "View Workers"
    },
    "inbox_introduction" => {
      title: "Your Command Center",
      description: "Your Inbox is the heart of your operations. Here you'll receive important messages, mission updates, and notifications about your fleet and trade routes.",
      highlight: "[data-menu-item='inbox']",
      icon: "📬",
      action_text: "Complete Tutorial"
    }
  }.freeze

  # Get configuration for a specific onboarding step
  # @param step [String, Symbol] The step name
  # @return [Hash] Configuration hash with title, description, highlight, icon
  def onboarding_step_config(step)
    STEP_CONFIGS[step.to_s] || {
      title: "Onboarding",
      description: "Continue your journey through StellArb.",
      highlight: nil,
      icon: "📍",
      action_text: "Continue"
    }
  end

  # Get progress information for user's onboarding
  # @param user [User] The user
  # @return [Hash] Hash with :current (1-indexed) and :total
  def onboarding_progress(user)
    return { current: 0, total: 0 } if user.onboarding_complete?

    current_index = User::ONBOARDING_STEPS.index(user.onboarding_step) || 0
    {
      current: current_index + 1,  # 1-indexed for display
      total: User::ONBOARDING_STEPS.length
    }
  end

  # Get progress percentage for progress bar
  # @param user [User] The user
  # @return [Integer] Percentage complete (0-100)
  def onboarding_progress_percentage(user)
    progress = onboarding_progress(user)
    return 100 if progress[:total].zero?

    ((progress[:current].to_f / progress[:total]) * 100).round
  end

  # Check if we should show the onboarding overlay
  # @param user [User, nil] The current user
  # @return [Boolean]
  def show_onboarding_overlay?(user)
    user&.needs_onboarding?
  end
end
