class InboxController < ApplicationController
  before_action :set_active_menu

  def index
    # For now, show sample messages
    # Later this will pull from a Message model
    @messages = [
      {
        id: 1,
        unread: true,
        title: "Welcome to StellArb!",
        from: "Colonial Authority",
        body: "Complete the tutorial to receive your exploration grant.",
        timestamp: 5.minutes.ago,
        urgent: false
      },
      {
        id: 2,
        unread: true,
        title: "Tutorial Quest Available",
        from: "System Guide",
        body: "Visit the Navigation panel to begin your first trading route.",
        timestamp: 10.minutes.ago,
        urgent: true
      }
    ]
  end

  def show
    # Placeholder - will load from database
    @message = {
      id: params[:id],
      title: "Welcome to StellArb!",
      from: "Colonial Authority",
      body: "Greetings, pilot. You've been selected for the Colonial Expansion Program...",
      timestamp: 5.minutes.ago
    }
  end

  private

  def set_active_menu
    super(:inbox)
  end
end
