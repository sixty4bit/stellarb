class InboxController < ApplicationController
  before_action :set_active_menu

  def index
    # For now, show sample messages
    # Later this will pull from a Message model
    @messages = sample_messages
  end

  def show
    # Placeholder - will load from database
    @message = sample_messages.find { |m| m[:id] == params[:id].to_i } || sample_messages.first
  end

  private

  def sample_messages
    [
      {
        id: 1,
        unread: true,
        urgent: false,
        title: "Welcome to StellArb!",
        from: "Colonial Authority",
        body: "Greetings, pilot.\n\nYou've been selected for the Colonial Expansion Program. As a new arrival to the frontier, you have been granted a starter vessel and a small credit line to begin your journey.\n\nYour first task: Visit the Navigation panel to plot a course to the nearest trade hub. There you can purchase supplies and accept your first contracts.\n\nMay the stars guide your path.\n\n— Colonial Authority Registration Division",
        timestamp: 5.minutes.ago
      },
      {
        id: 2,
        unread: true,
        urgent: true,
        title: "Tutorial Quest Available",
        from: "System Guide",
        body: "PRIORITY NOTIFICATION\n\nA tutorial quest has been unlocked for your account. Completing this quest will grant you:\n\n• 500 Credits\n• Basic Scanner Module\n• Navigation Chart: Local Sector\n\nTo begin, access the Navigation panel from the main menu.\n\nThis quest will expire in 72 hours.",
        timestamp: 10.minutes.ago
      }
    ]
  end

  def set_active_menu
    super(:inbox)
  end
end
