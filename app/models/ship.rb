class Ship < ApplicationRecord
  include TripleId

  # Travel result struct for returning success/failure with details
  TravelResult = Struct.new(:success?, :error, keyword_init: true) do
    def self.success
      new(success?: true)
    end

    def self.failure(error)
      new(success?: false, error: error)
    end
  end

  # Constants
  BASE_SPEED = 1.0  # Base travel speed (units per second)
  MANEUVERABILITY_BASELINE = 50  # Standard maneuverability for speed calculations

  # Associations
  belongs_to :user
  belongs_to :current_system, class_name: 'System', optional: true
  belongs_to :destination_system, class_name: 'System', optional: true
  has_many :hirings, as: :assignable, dependent: :destroy
  has_many :crew, through: :hirings, source: :hired_recruit

  # Constants
  RACES = %w[vex solari krog myrmidon].freeze
  HULL_SIZES = %w[scout frigate transport cruiser titan].freeze
  STATUSES = %w[docked in_transit combat destroyed].freeze
  INTENTS = %w[trade battle].freeze

  # Validations
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :race, presence: true, inclusion: { in: RACES }
  validates :hull_size, presence: true, inclusion: { in: HULL_SIZES }
  validates :variant_idx, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fuel, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Either current_system or location coordinates must be present
  validate :must_have_location

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :generate_ship_attributes, on: :create

  # Scopes
  scope :active, -> { where.not(status: 'destroyed') }
  scope :docked, -> { where(status: 'docked') }
  scope :in_transit, -> { where(status: 'in_transit') }
  scope :trading, -> { where(system_intent: 'trade') }
  scope :hostile, -> { where(system_intent: 'battle') }

  # Travel calculations
  def fuel_efficiency
    ship_attributes["fuel_efficiency"] || 1.0
  end

  def maneuverability
    ship_attributes["maneuverability"] || MANEUVERABILITY_BASELINE
  end

  def fuel_required_for(destination)
    return 0 if destination == current_system
    distance = System.distance_between(current_system, destination)
    distance * fuel_efficiency
  end

  def can_reach?(destination)
    fuel >= fuel_required_for(destination)
  end

  def travel_time_to(destination)
    return 0 if destination == current_system
    distance = System.distance_between(current_system, destination)
    speed_multiplier = maneuverability.to_f / MANEUVERABILITY_BASELINE
    (distance / (BASE_SPEED * speed_multiplier)).ceil
  end

  def travel_to!(destination, intent: :trade)
    # Validate intent
    intent_str = intent.to_s
    unless INTENTS.include?(intent_str)
      return TravelResult.failure("Invalid intent '#{intent}'. Must be one of: #{INTENTS.join(', ')}")
    end

    # Validate travel is possible
    if status == "in_transit"
      return TravelResult.failure("Ship is already in transit")
    end

    if destination == current_system || destination.id == current_system_id
      return TravelResult.failure("Ship is already at this location")
    end

    fuel_needed = fuel_required_for(destination)
    if fuel < fuel_needed
      return TravelResult.failure("Insufficient fuel (need #{fuel_needed}, have #{fuel})")
    end

    # Clear current intent when leaving (unlocks intent)
    clear_intent!

    # Initiate travel with pending intent
    travel_time = travel_time_to(destination)
    self.fuel -= fuel_needed
    self.status = "in_transit"
    self.destination_system = destination
    self.arrival_at = Time.current + travel_time.seconds
    self.pending_intent = intent_str
    save!

    TravelResult.success
  end

  def check_arrival!
    return unless status == "in_transit" && arrival_at.present?
    return if arrival_at > Time.current

    # Arrive at destination
    self.current_system = destination_system
    self.destination_system = nil
    self.arrival_at = nil

    # Apply the pending intent
    apply_intent!(pending_intent || "trade")
    self.pending_intent = nil
    save!
  end

  # Warp travel (instant via warp gates)
  def warp_fuel_required_for(destination)
    return 0 if destination == current_system
    WarpGate::WARP_FUEL_COST
  end

  def can_warp_to?(destination)
    return false unless current_system.warp_connected_to?(destination)
    fuel >= warp_fuel_required_for(destination)
  end

  def warp_to!(destination, intent: :trade)
    # Validate intent
    intent_str = intent.to_s
    unless INTENTS.include?(intent_str)
      return TravelResult.failure("Invalid intent '#{intent}'. Must be one of: #{INTENTS.join(', ')}")
    end

    # Validate warp is possible
    if status == "in_transit"
      return TravelResult.failure("Ship is already in transit")
    end

    if destination == current_system || destination.id == current_system_id
      return TravelResult.failure("Ship is already at this location")
    end

    # Check for warp gate connection
    gate = WarpGate.between(current_system, destination)
    unless gate
      return TravelResult.failure("No warp gate connects these systems")
    end

    unless gate.active?
      return TravelResult.failure("Warp gate is offline")
    end

    fuel_needed = warp_fuel_required_for(destination)
    if fuel < fuel_needed
      return TravelResult.failure("Insufficient fuel for warp (need #{fuel_needed}, have #{fuel})")
    end

    # Clear current intent when leaving
    clear_intent!

    # Execute instant warp and apply intent immediately
    self.fuel -= fuel_needed
    self.current_system = destination
    apply_intent!(intent_str)
    save!

    TravelResult.success
  end

  # Intent helper methods
  def trading?
    system_intent == "trade"
  end

  def hostile?
    system_intent == "battle"
  end

  def under_defense_alert?
    defense_engaged_at.present?
  end

  def change_intent!(new_intent)
    # Intent is locked while present in a system
    if system_intent.present?
      return TravelResult.failure("Intent is locked while in system. Leave the system first.")
    end

    intent_str = new_intent.to_s
    unless INTENTS.include?(intent_str)
      return TravelResult.failure("Invalid intent '#{new_intent}'")
    end

    apply_intent!(intent_str)
    save!
    TravelResult.success
  end

  def clear_intent!
    self.system_intent = nil
    self.defense_engaged_at = nil
  end

  # Attribute for pending intent during transit
  attr_accessor :pending_intent

  private

  def apply_intent!(intent_str)
    self.system_intent = intent_str

    if intent_str == "battle"
      # Battle intent triggers defense grid
      self.defense_engaged_at = Time.current
      self.status = "combat"
    else
      self.status = "docked"
      self.defense_engaged_at = nil
    end
  end

  def generate_short_id
    return if short_id.present?

    base = "sh-#{name[0, 3].downcase}" if name.present?
    base ||= "sh-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while Ship.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def generate_ship_attributes
    return if ship_attributes.present?

    # This is a placeholder - would use the procedural generation engine
    base_stats = {
      cargo_capacity: 100,
      fuel_efficiency: 1.0,
      maneuverability: 50,
      hardpoints: 2,
      crew_slots: { min: 2, max: 4 },
      maintenance_rate: 10,
      hull_points: 100,
      sensor_range: 10
    }

    # Apply racial bonuses
    case race
    when 'vex'
      base_stats[:cargo_capacity] *= 1.2
    when 'solari'
      base_stats[:sensor_range] *= 1.2
    when 'krog'
      base_stats[:hull_points] *= 1.2
    when 'myrmidon'
      base_stats[:maintenance_rate] *= 0.8
    end

    self.ship_attributes = base_stats
  end

  def must_have_location
    if current_system_id.blank? && (location_x.blank? || location_y.blank? || location_z.blank?)
      errors.add(:base, "Ship must have either a current system or location coordinates")
    end
  end
end
