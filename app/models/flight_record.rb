class FlightRecord < ApplicationRecord
  # Associations
  belongs_to :ship
  belongs_to :user
  belongs_to :from_system, class_name: 'System'
  belongs_to :to_system, class_name: 'System'

  # Constants
  EVENT_TYPES = %w[departure arrival emigration_teleport].freeze

  # Validations
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validates :distance, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :departures, -> { where(event_type: 'departure') }
  scope :arrivals, -> { where(event_type: 'arrival') }
  scope :emigration_teleports, -> { where(event_type: 'emigration_teleport') }
  scope :recent_first, -> { order(occurred_at: :desc) }

  # ===========================================
  # Record Methods
  # ===========================================

  # Record a ship departure
  # @param ship [Ship] The ship departing
  # @param from_system [System] Origin system
  # @param to_system [System] Destination system
  # @return [FlightRecord]
  def self.record_departure(ship, from_system, to_system)
    create!(
      ship: ship,
      user: ship.user,
      from_system: from_system,
      to_system: to_system,
      event_type: 'departure',
      occurred_at: Time.current,
      distance: System.distance_between(from_system, to_system)
    )
  end

  # Record a ship arrival
  # @param ship [Ship] The ship arriving
  # @param from_system [System] Origin system
  # @param to_system [System] Destination system
  # @return [FlightRecord]
  def self.record_arrival(ship, from_system, to_system)
    create!(
      ship: ship,
      user: ship.user,
      from_system: from_system,
      to_system: to_system,
      event_type: 'arrival',
      occurred_at: Time.current,
      distance: System.distance_between(from_system, to_system)
    )
  end
end
