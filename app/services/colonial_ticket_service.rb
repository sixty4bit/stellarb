# frozen_string_literal: true

# ColonialTicketService manages the Phase 2 -> Phase 3 transition
# The Colonial Ticket is unlocked when Proving Ground objectives are complete
class ColonialTicketService
  # Result struct for ticket operations
  TicketResult = Struct.new(:success?, :error, :ticket, keyword_init: true) do
    def self.success(ticket:)
      new(success?: true, ticket: ticket)
    end

    def self.failure(error)
      new(success?: false, error: error)
    end
  end

  # Check if user has completed Proving Ground requirements
  # Requirements:
  # 1. Discovered at least one system (via scan/visit)
  # 2. Constructed at least one building
  #
  # @param user [User] The user to check
  # @return [Boolean]
  def self.proving_ground_complete?(user:)
    progress = proving_ground_progress(user: user)
    progress[:overall_complete]
  end

  # Get detailed progress through Proving Ground phase
  # @param user [User] The user to check
  # @return [Hash] Progress details
  def self.proving_ground_progress(user:)
    scan_complete = user.system_visits.any?
    building_complete = user.buildings.where(status: %w[active under_construction]).any?

    {
      scan_complete: scan_complete,
      building_complete: building_complete,
      overall_complete: scan_complete && building_complete,
      details: {
        systems_discovered: user.system_visits.count,
        buildings_constructed: user.buildings.count
      }
    }
  end

  # Unlock the Colonial Ticket and advance to Emigration phase
  # @param user [User] The user unlocking the ticket
  # @return [TicketResult]
  def self.unlock_colonial_ticket(user:)
    new(user: user).unlock
  end

  # Check if user is ready for ticket and unlock automatically if so
  # Safe to call at any time - will only unlock if all requirements met
  # @param user [User] The user to check
  # @return [TicketResult]
  def self.check_and_unlock_if_ready(user:)
    return TicketResult.failure("Not in proving ground phase") unless user.proving_ground?
    return TicketResult.failure("Requirements not met") unless proving_ground_complete?(user: user)

    result = unlock_colonial_ticket(user: user)

    # Send inbox message on successful unlock
    if result.success?
      send_ticket_notification(user: user, ticket: result.ticket)
    end

    result
  end

  # Send inbox notification about Colonial Ticket unlock
  # @param user [User] The recipient
  # @param ticket [Hash] The ticket info
  def self.send_ticket_notification(user:, ticket:)
    Message.create!(
      user: user,
      category: "tutorial",
      from: "Colonial Authority",
      title: "Colonial Ticket Unlocked!",
      body: <<~MSG.strip
        Congratulations, #{user.name}!

        You have completed the Proving Ground and earned your Colonial Ticket.
        The stars are calling — it's time for emigration.

        Your ticket grants passage to the frontier. Choose your destination
        wisely, for the Drop is one-way.

        Systems discovered: #{ticket[:progress_summary][:systems_discovered]}
        Buildings constructed: #{ticket[:progress_summary][:buildings_constructed]}

        May the void be kind to you.
      MSG
    )
  end

  def initialize(user:)
    @user = user
  end

  def unlock
    return TicketResult.failure("Must be in proving ground phase") unless @user.proving_ground?
    return TicketResult.failure("Requirements not met: Complete a scan and build a structure") unless self.class.proving_ground_complete?(user: @user)

    ticket = generate_ticket
    advance_to_emigration!

    TicketResult.success(ticket: ticket)
  rescue ActiveRecord::RecordInvalid => e
    TicketResult.failure("Failed to unlock ticket: #{e.message}")
  end

  private

  def generate_ticket
    # The Colonial Ticket is a one-time pass to the Emigration phase
    # In a full implementation, this might be stored in a separate table
    # For now, we track it via the user's phase transition
    {
      ticket_id: SecureRandom.uuid,
      user_id: @user.id,
      user_name: @user.name,
      issued_at: Time.current,
      valid_for: "one_time_drop",
      status: "active",
      progress_summary: self.class.proving_ground_progress(user: @user)[:details]
    }
  end

  def advance_to_emigration!
    @user.update!(tutorial_phase: :emigration)
  end
end
