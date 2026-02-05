class Route < ApplicationRecord
  include TripleId

  belongs_to :user
  belongs_to :ship, optional: true

  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active paused completed] }

  before_validation :generate_short_id, on: :create
  after_commit :check_tutorial_completion, on: [:create, :update]

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :paused, -> { where(status: "paused") }

  # Generate short ID from route stops
  def generate_short_id
    return if short_id.present?

    if stops.any? && stops.is_a?(Array)
      # First letter of each stop
      letters = stops.map { |stop| stop["name"]&.first&.downcase }.compact.join
      base = "rt-#{letters}"
    else
      base = "rt-#{SecureRandom.hex(3)}"
    end

    candidate = base
    counter = 2

    while Route.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  # Calculate profit per hour based on recent performance
  def calculate_profit_per_hour!
    return 0.0 unless loop_count > 0 && created_at < 1.hour.ago

    hours_active = (Time.current - created_at) / 1.hour
    self.profit_per_hour = total_profit / hours_active
    save!
  end

  # ===========================================
  # Tutorial Support Methods
  # ===========================================

  # Check if route has any stops defined
  # @return [Boolean]
  def has_stops?
    stops.is_a?(Array) && stops.any?
  end

  # Check if route is profitable
  # @return [Boolean]
  def profitable?
    total_profit.present? && total_profit > 0
  end

  # Check if all stops are within The Cradle (0,0,0)
  # @return [Boolean]
  def within_cradle?
    return false unless has_stops?

    system_ids = stops.map { |stop| stop["system_id"] || stop[:system_id] }.compact
    return false if system_ids.empty?

    systems = System.where(id: system_ids)
    systems.any? && systems.all?(&:is_cradle?)
  end

  # Check if route qualifies for tutorial completion
  # Must be: active, profitable, and have stops
  # @return [Boolean]
  def qualifies_for_tutorial?
    status == "active" && profitable? && has_stops?
  end

  # Check if route meets supply chain tutorial criteria
  # Same as qualifies_for_tutorial? but semantically distinct
  # @return [Boolean]
  def meets_supply_chain_tutorial?
    qualifies_for_tutorial?
  end

  # Check if route involves a specific commodity in any stop
  # @param commodity [String] the commodity name to check
  # @return [Boolean]
  def involves_commodity?(commodity)
    return false unless has_stops?

    stops.any? do |stop|
      (stop["commodity"] || stop[:commodity]).to_s.downcase == commodity.to_s.downcase
    end
  end

  private

  # Callback: Check if this route's creation/update completes the tutorial
  # Called after commit to ensure data is persisted
  # Advances user tutorial phase if eligible
  # @return [Boolean] whether the route qualifies for tutorial completion
  def check_tutorial_completion
    return false unless qualifies_for_tutorial?

    advance_user_tutorial_if_eligible
    true
  end

  # Advance the user's tutorial phase if they're in cradle and this route qualifies
  # Only advances from cradle -> proving_ground
  def advance_user_tutorial_if_eligible
    return unless user.cradle?
    return unless meets_supply_chain_tutorial?

    user.advance_tutorial_phase!
  end
end