class Route < ApplicationRecord
  include TripleId

  belongs_to :user
  belongs_to :ship, optional: true

  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active paused completed] }

  before_validation :generate_short_id, on: :create

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
end