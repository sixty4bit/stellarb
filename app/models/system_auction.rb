# frozen_string_literal: true

# Auction for abandoned system ownership
# When an owner is inactive for 30 days, their systems go to auction
class SystemAuction < ApplicationRecord
  # Configuration
  DURATION_HOURS = 48
  INACTIVITY_THRESHOLD_DAYS = 30
  WARNING_DAYS = [5, 3, 1].freeze
  MINIMUM_BID = 100
  MINIMUM_INCREMENT = 10

  # Statuses
  STATUSES = %w[pending active completed cancelled].freeze

  # Associations
  belongs_to :system
  belongs_to :previous_owner, class_name: "User", optional: true
  belongs_to :winning_bid, class_name: "SystemAuctionBid", optional: true
  has_many :bids, class_name: "SystemAuctionBid", foreign_key: :auction_id, dependent: :destroy

  # Validations
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :uuid, uniqueness: true, allow_nil: true
  validates :system_id, uniqueness: { scope: :status, message: "already has an active auction" },
            if: -> { status.in?(%w[pending active]) }

  # Callbacks
  before_create :generate_uuid

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :ended, -> { active.where("ends_at <= ?", Time.current) }
  scope :for_system, ->(system) { where(system: system) }

  # Start the auction (transition from pending to active)
  def start!
    return false unless pending?

    update!(
      status: "active",
      started_at: Time.current,
      ends_at: DURATION_HOURS.hours.from_now
    )
  end

  # Cancel the auction (owner reclaimed their system)
  def cancel!(reason: "owner_reclaimed")
    return false unless active? || pending?

    transaction do
      refund_all_bids!
      update!(status: "cancelled")
    end

    true
  end

  # Complete the auction (transfer ownership to winner)
  def complete!
    return false unless active?
    return false unless ended?

    transaction do
      if highest_bid
        # Transfer ownership
        system.update!(owner: highest_bid.user, owner_last_visit_at: Time.current)

        # Mark winning bid
        update!(status: "completed", winning_bid: highest_bid)

        # Burn all bid amounts (money sink - credits already escrowed)
        burn_all_bids!

        # Notify winner
        notify_winner(highest_bid.user)
      else
        # No bids - system becomes unowned
        system.update!(owner: nil, owner_last_visit_at: nil)
        update!(status: "completed")
      end

      # Notify previous owner
      notify_previous_owner_of_completion if previous_owner
    end

    true
  end

  # Place a bid
  def place_bid!(user, amount)
    raise "Auction not active" unless active?
    raise "Auction has ended" if ended?
    raise "Cannot bid on your own system" if user == previous_owner
    raise "Bid too low" if amount < minimum_bid

    # Check user has enough credits
    raise "Insufficient credits" if user.credits < amount

    transaction do
      # Refund previous highest bid (they're being outbid)
      previous_highest = highest_bid
      if previous_highest && previous_highest.user != user
        previous_highest.refund!
        previous_highest.destroy!
      end

      # Refund previous bid from this user if any (they're increasing their bid)
      existing_bid = bids.find_by(user: user)
      if existing_bid
        existing_bid.refund!
        existing_bid.destroy!
      end

      # Reload user to get current credits after any refunds
      user.reload

      # Escrow the new bid amount
      user.update!(credits: user.credits - amount)

      # Create new bid
      bids.create!(
        user: user,
        amount: amount,
        placed_at: Time.current
      )
    end
  end

  # Get the current highest bid
  def highest_bid
    bids.order(amount: :desc).first
  end

  # Get the current highest bid amount
  def current_bid
    highest_bid&.amount || 0
  end

  # Calculate minimum bid based on current highest
  def minimum_bid
    if bids.any?
      current_bid + MINIMUM_INCREMENT
    else
      MINIMUM_BID
    end
  end

  # Check if auction has ended (time expired)
  def ended?
    ends_at.present? && ends_at <= Time.current
  end

  # Status helpers
  def pending?
    status == "pending"
  end

  def active?
    status == "active"
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end

  # Class method: Create auction for inactive system
  def self.create_for_inactive_system!(system)
    return if for_system(system).pending.exists? || for_system(system).active.exists?

    auction = create!(
      system: system,
      previous_owner: system.owner,
      status: "pending"
    )

    # Start it immediately
    auction.start!
    auction
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def refund_all_bids!
    bids.find_each(&:refund!)
  end

  def burn_all_bids!
    # All credits are already escrowed (deducted from users)
    # We simply don't return them - they're burned as a money sink
    # Nothing to do here - the credits just vanish from the economy
  end

  def notify_winner(user)
    Message.create!(
      user: user,
      from: "Galactic Trade Authority",
      title: "Auction Won: #{system.name}",
      body: "Congratulations! You have won the auction for #{system.name}. " \
            "The system is now under your ownership. Your winning bid of #{highest_bid.amount} credits " \
            "has been processed.",
      category: "auction",
      urgent: true
    )
  end

  def notify_previous_owner_of_completion
    if winning_bid
      Message.create!(
        user: previous_owner,
        from: "Galactic Trade Authority",
        title: "System Seized: #{system.name}",
        body: "Due to extended inactivity, #{system.name} has been seized and auctioned. " \
              "The winning bid was #{winning_bid.amount} credits. " \
              "Visit your systems regularly to prevent future seizures.",
        category: "auction",
        urgent: true
      )
    else
      Message.create!(
        user: previous_owner,
        from: "Galactic Trade Authority",
        title: "System Seized: #{system.name}",
        body: "Due to extended inactivity, #{system.name} has been seized. " \
              "No bids were placed, so the system is now unclaimed. " \
              "Visit your systems regularly to prevent future seizures.",
        category: "auction",
        urgent: true
      )
    end
  end
end
