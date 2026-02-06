class SystemVisit < ApplicationRecord
  belongs_to :user
  belongs_to :system

  validates :first_visited_at, presence: true
  validates :last_visited_at, presence: true
  validates :visit_count, presence: true, numericality: { greater_than: 0 }
  validates :user_id, uniqueness: { scope: :system_id, message: "has already visited this system" }

  # Scopes for ordering
  scope :by_first_visit, -> { order(first_visited_at: :asc) }
  scope :by_last_visit, -> { order(last_visited_at: :desc) }

  # Record a new visit to a system
  # Automatically snapshots current prices when visiting
  def self.record_visit(user, system)
    visit = find_or_initialize_by(user: user, system: system)

    if visit.new_record?
      visit.first_visited_at = Time.current
      visit.last_visited_at = Time.current
      visit.visit_count = 1
    else
      visit.last_visited_at = Time.current
      visit.visit_count += 1
    end

    # Always snapshot prices on visit
    visit.snapshot_prices!

    visit.save!
    visit
  end

  # ===========================================
  # Price Snapshot Methods (Fog of War)
  # ===========================================

  # Capture current system prices into the snapshot
  # Called when a player visits or departs a system
  def snapshot_prices!
    self.price_snapshot = system.current_prices
  end

  # Get the snapshot timestamp (when prices were last seen)
  # This is the last_visited_at time when the snapshot was taken
  # @return [Time]
  def snapshot_at
    last_visited_at
  end

  # Calculate how stale the price data is
  # @return [ActiveSupport::Duration, nil] Time since snapshot, or nil if no snapshot
  def staleness
    return nil unless snapshot_at.present?
    Time.current - snapshot_at
  end

  # Check if the price snapshot is considered stale
  # @param threshold [ActiveSupport::Duration] Duration after which prices are stale (default: 1 hour)
  # @return [Boolean]
  def stale?(threshold: 1.hour)
    return true unless snapshot_at.present?
    staleness > threshold
  end

  # Human-readable staleness label
  # @return [String] e.g., "2 hours ago", "just now", "unknown"
  def staleness_label
    return "never visited" unless snapshot_at.present?

    seconds = staleness.to_i
    return "just now" if seconds < 60

    minutes = seconds / 60
    return "#{minutes} minute#{'s' if minutes != 1} ago" if minutes < 60

    hours = minutes / 60
    return "#{hours} hour#{'s' if hours != 1} ago" if hours < 24

    days = hours / 24
    "#{days} day#{'s' if days != 1} ago"
  end

  # Get prices from the snapshot (what the player remembers)
  # @return [Hash] Commodity => price
  def remembered_prices
    price_snapshot || {}
  end

  # Check if we have a valid price snapshot
  # @return [Boolean]
  def has_price_snapshot?
    price_snapshot.present? && price_snapshot.any?
  end
end