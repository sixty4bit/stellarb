class Route < ApplicationRecord
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
end