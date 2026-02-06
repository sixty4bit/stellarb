class Ship < ApplicationRecord
  include TripleId
  include Turbo::Broadcastable

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

  # ===========================================
  # Ship Costs Configuration
  # ===========================================
  # Base credits cost for each hull size
  # Costs scale with ship complexity and capability
  SHIP_COSTS = {
    "scout" => { base_credits: 500 },
    "frigate" => { base_credits: 1500 },
    "transport" => { base_credits: 3000 },
    "cruiser" => { base_credits: 7500 },
    "titan" => { base_credits: 20000 }
  }.freeze

  # Racial cost modifiers (percentage adjustment)
  RACIAL_COST_MODIFIERS = {
    "vex" => 1.0,        # Standard pricing
    "solari" => 1.1,     # Premium for advanced sensors
    "krog" => 1.15,      # Premium for reinforced hulls
    "myrmidon" => 0.9    # Discount due to efficient manufacturing
  }.freeze

  # Ship type display names
  SHIP_TYPE_NAMES = {
    "scout" => "Scout Vessel",
    "frigate" => "Light Frigate",
    "transport" => "Cargo Transport",
    "cruiser" => "Battle Cruiser",
    "titan" => "Capital Titan"
  }.freeze

  # ===========================================
  # Ship Cost Calculations
  # ===========================================

  # Calculate the cost for a ship with given hull size and race
  # @param hull_size [String] One of HULL_SIZES
  # @param race [String] One of RACES
  # @return [Integer] Total credits cost
  def self.cost_for(hull_size:, race:)
    validate_ship_params!(hull_size: hull_size, race: race)

    base_cost = SHIP_COSTS[hull_size][:base_credits]
    modifier = RACIAL_COST_MODIFIERS[race]
    (base_cost * modifier).round
  end

  # Return all purchasable ship configurations
  # @return [Array<Hash>] Array of ship type configurations
  def self.purchasable_types
    types = []
    HULL_SIZES.each do |hull_size|
      RACES.each do |race|
        types << {
          hull_size: hull_size,
          race: race,
          cost: cost_for(hull_size: hull_size, race: race),
          name: "#{race.capitalize} #{SHIP_TYPE_NAMES[hull_size]}"
        }
      end
    end
    types
  end

  private_class_method def self.validate_ship_params!(hull_size:, race:)
    unless HULL_SIZES.include?(hull_size)
      raise ArgumentError, "Invalid hull_size: #{hull_size}. Must be one of: #{HULL_SIZES.join(', ')}"
    end
    unless RACES.include?(race)
      raise ArgumentError, "Invalid race: #{race}. Must be one of: #{RACES.join(', ')}"
    end
  end

  # ===========================================
  # Ship Upgrade System
  # ===========================================
  
  # Base costs for upgrading each attribute (per upgrade level)
  UPGRADE_COSTS = {
    "cargo_capacity" => { base: 200, per_level: 50 },
    "fuel_efficiency" => { base: 300, per_level: 100 },
    "maneuverability" => { base: 250, per_level: 75 },
    "hardpoints" => { base: 500, per_level: 200 },
    "hull_points" => { base: 400, per_level: 100 },
    "sensor_range" => { base: 150, per_level: 50 }
  }.freeze

  # How much each attribute increases per upgrade
  UPGRADE_AMOUNTS = {
    "cargo_capacity" => 20,       # +20 cargo space
    "fuel_efficiency" => -0.1,    # -0.1 fuel consumption (better efficiency)
    "maneuverability" => 5,       # +5 maneuverability
    "hardpoints" => 1,            # +1 hardpoint
    "hull_points" => 15,          # +15 hull points
    "sensor_range" => 2           # +2 sensor range
  }.freeze

  # Maximum upgrades per attribute by hull size
  MAX_UPGRADES = {
    "scout" => 3,
    "frigate" => 4,
    "transport" => 5,
    "cruiser" => 6,
    "titan" => 8
  }.freeze

  # Calculate upgrade cost for an attribute
  # @param attribute [String] Attribute to upgrade
  # @return [Integer] Credits cost
  def upgrade_cost_for(attribute)
    validate_upgradable_attribute!(attribute)
    
    current_upgrades = upgrade_count_for(attribute)
    cost_config = UPGRADE_COSTS[attribute]
    
    (cost_config[:base] + (cost_config[:per_level] * current_upgrades)).round
  end

  # Get list of upgradable attributes with their current values and costs
  # @return [Array<Hash>]
  def upgradable_attributes
    UPGRADE_COSTS.keys.map do |attr|
      {
        name: attr,
        display_name: attr.humanize,
        current_value: ship_attributes[attr],
        cost: upgrade_cost_for(attr),
        upgrade_amount: UPGRADE_AMOUNTS[attr],
        current_upgrades: upgrade_count_for(attr),
        max_upgrades: MAX_UPGRADES[hull_size],
        can_upgrade: can_upgrade?(attr)
      }
    end
  end

  # Check if an attribute can be upgraded
  # @param attribute [String] Attribute to check
  # @return [Boolean]
  def can_upgrade?(attribute)
    upgrade_count_for(attribute) < MAX_UPGRADES[hull_size]
  end

  # Perform an upgrade on the ship
  # @param attribute [String] Attribute to upgrade
  # @param user [User] User paying for the upgrade
  # @return [TravelResult] Success/failure result
  def upgrade!(attribute, user)
    # Validate attribute
    unless UPGRADE_COSTS.key?(attribute)
      return TravelResult.failure("Invalid attribute: #{attribute}")
    end

    # Check upgrade limit
    unless can_upgrade?(attribute)
      return TravelResult.failure("Maximum upgrade limit reached for #{attribute}")
    end

    # Check affordability
    cost = upgrade_cost_for(attribute)
    if user.credits < cost
      return TravelResult.failure("Insufficient credits (need #{cost}, have #{user.credits.to_i})")
    end

    ActiveRecord::Base.transaction do
      # Deduct credits
      user.update!(credits: user.credits - cost)

      # Apply upgrade
      ship_attributes[attribute] = (ship_attributes[attribute] || 0) + UPGRADE_AMOUNTS[attribute]
      
      # Track upgrade count
      ship_attributes["upgrades"] ||= {}
      ship_attributes["upgrades"][attribute] = upgrade_count_for(attribute) + 1
      
      save!
    end

    TravelResult.success
  end

  private

  def upgrade_count_for(attribute)
    ship_attributes.dig("upgrades", attribute) || 0
  end

  def validate_upgradable_attribute!(attribute)
    unless UPGRADE_COSTS.key?(attribute)
      raise ArgumentError, "Invalid attribute: #{attribute}. Must be one of: #{UPGRADE_COSTS.keys.join(', ')}"
    end
  end

  public

  # ===========================================
  # Refueling System
  # ===========================================
  
  # Default fuel price if system doesn't have market data
  DEFAULT_FUEL_PRICE = 100

  # Get the current fuel price at the ship's current system
  # @return [Integer] Price per unit of fuel
  def current_fuel_price
    return DEFAULT_FUEL_PRICE unless current_system.present?
    
    # Check system's base prices for fuel
    base_price = current_system.base_prices["fuel"] || DEFAULT_FUEL_PRICE
    
    # Add any price delta from the market
    delta = PriceDelta.find_by(system: current_system, commodity: "fuel")&.delta_cents || 0
    
    (base_price + delta).to_i
  end

  # Calculate the cost to refuel a specific amount
  # @param amount [Numeric] Amount of fuel to purchase
  # @return [Integer] Total cost in credits
  def refuel_cost_for(amount)
    (amount * current_fuel_price).to_i
  end

  # Calculate fuel needed to reach full capacity
  # @return [Numeric] Units of fuel needed
  def fuel_needed_to_fill
    fuel_capacity - fuel
  end

  # Refuel the ship by purchasing fuel from the current system's market
  # @param amount [Numeric] Amount of fuel to purchase
  # @param user [User] User paying for the fuel
  # @return [TravelResult] Success/failure result
  def refuel!(amount, user)
    # Must be docked at a system
    unless status == "docked" && current_system.present?
      return TravelResult.failure("Ship must be docked at a system to refuel")
    end

    # Check if amount would exceed capacity
    if fuel + amount > fuel_capacity
      return TravelResult.failure("Cannot exceed fuel capacity (#{fuel_capacity})")
    end

    # Calculate cost
    cost = refuel_cost_for(amount)
    
    # Check if user has enough credits
    if user.credits < cost
      return TravelResult.failure("Insufficient credits (need #{cost}, have #{user.credits.to_i})")
    end

    ActiveRecord::Base.transaction do
      user.update!(credits: user.credits - cost)
      self.fuel += amount
      save!
    end

    TravelResult.success
  end

  # Refuel to full capacity
  # @param user [User] User paying for the fuel
  # @return [TravelResult] Success/failure result
  def refuel_to_full!(user)
    amount = fuel_needed_to_fill
    return TravelResult.success if amount <= 0
    
    refuel!(amount, user)
  end

  # ===========================================
  # Cargo System
  # ===========================================
  
  # Get the cargo capacity from ship attributes
  # @return [Integer] Maximum cargo capacity in units
  def cargo_capacity
    ship_attributes["cargo_capacity"]&.to_i || 100
  end

  # Calculate total weight of all cargo
  # @return [Integer] Total cargo weight in units
  def total_cargo_weight
    (cargo || {}).values.sum(&:to_i)
  end

  # Calculate available cargo space
  # @return [Integer] Available space in units
  def available_cargo_space
    cargo_capacity - total_cargo_weight
  end

  # Get quantity of a specific commodity in cargo
  # @param commodity [String] Commodity name
  # @return [Integer] Quantity in cargo (0 if not present)
  def cargo_quantity_for(commodity)
    (cargo || {})[commodity].to_i
  end

  # Add cargo to the ship
  # @param commodity [String] Commodity to add
  # @param quantity [Integer] Amount to add
  # @return [TravelResult] Success/failure result
  def add_cargo!(commodity, quantity)
    quantity = quantity.to_i
    
    # Check capacity
    if total_cargo_weight + quantity > cargo_capacity
      return TravelResult.failure("Cannot exceed cargo capacity (#{available_cargo_space} available)")
    end

    self.cargo ||= {}
    self.cargo[commodity] = cargo_quantity_for(commodity) + quantity
    save!

    TravelResult.success
  end

  # Remove cargo from the ship
  # @param commodity [String] Commodity to remove
  # @param quantity [Integer] Amount to remove
  # @return [TravelResult] Success/failure result
  def remove_cargo!(commodity, quantity)
    quantity = quantity.to_i
    current_qty = cargo_quantity_for(commodity)
    
    # Check if we have this commodity
    if current_qty == 0
      return TravelResult.failure("You don't have any #{commodity} in cargo")
    end

    # Check if we have enough
    if current_qty < quantity
      return TravelResult.failure("Insufficient #{commodity} in cargo (have #{current_qty}, need #{quantity})")
    end

    self.cargo ||= {}
    new_qty = current_qty - quantity
    
    if new_qty <= 0
      self.cargo.delete(commodity)
    else
      self.cargo[commodity] = new_qty
    end
    
    save!
    TravelResult.success
  end

  # Associations
  belongs_to :user
  belongs_to :current_system, class_name: 'System', optional: true
  belongs_to :destination_system, class_name: 'System', optional: true
  has_many :hirings, as: :assignable, dependent: :destroy
  has_many :crew, through: :hirings, source: :hired_recruit
  has_many :flight_records, dependent: :destroy
  has_many :incidents, as: :asset, dependent: :destroy

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
  scope :disabled, -> { where.not(disabled_at: nil) }
  scope :operational, -> { where(disabled_at: nil).where.not(status: 'destroyed') }

  # Disabled state (pip infestation)
  def disabled?
    disabled_at.present?
  end

  def operational?
    !disabled? && status != 'destroyed'
  end

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

    # Store destination name before clearing
    arrived_at_system = destination_system

    # Record system visit and check if it's a first visit
    visit = SystemVisit.record_visit(user, arrived_at_system)
    is_first_visit = visit.visit_count == 1

    # Arrive at destination
    self.current_system = arrived_at_system
    self.location_x = arrived_at_system.x
    self.location_y = arrived_at_system.y
    self.location_z = arrived_at_system.z
    self.destination_system = nil
    self.arrival_at = nil

    # Apply the pending intent
    apply_intent!(pending_intent || "trade")
    self.pending_intent = nil
    save!

    # Send arrival notification to inbox
    send_arrival_notification(arrived_at_system)

    # Send discovery notification for first visits
    send_discovery_notification(arrived_at_system) if is_first_visit

    # Broadcast arrival to user's ships stream
    broadcast_arrival
  end

  def send_arrival_notification(system)
    Message.create!(
      user: user,
      title: "Arrival at #{system.name}",
      body: "Your ship #{name} has arrived at #{system.name}.",
      from: "Navigation System",
      category: "travel"
    )
  end

  def send_discovery_notification(system)
    star_type = system.properties&.dig("star_type")&.humanize || "unknown type"
    hazard = system.properties&.dig("hazard_level") || 0

    Message.create!(
      user: user,
      title: "🌟 New System Discovered: #{system.name}",
      body: "Congratulations, explorer! You are the first to visit #{system.name}.\n\n" \
            "Star Type: #{star_type}\n" \
            "Hazard Level: #{hazard}%\n" \
            "Coordinates: (#{system.x}, #{system.y}, #{system.z})\n\n" \
            "This discovery has been recorded in your flight log.",
      from: "Exploration Bureau",
      category: "discovery"
    )
  end

  # Returns the Turbo Stream target for this user's ships stream
  def broadcast_arrival_target
    "ships_user_#{user_id}"
  end

  # Broadcasts ship arrival to user's ships stream via Turbo Streams
  # Gracefully handles missing ActionCable in test environment
  def broadcast_arrival
    return unless defined?(ActionCable)

    broadcast_replace_later_to(
      broadcast_arrival_target,
      target: ActionView::RecordIdentifier.dom_id(self),
      partial: "ships/ship",
      locals: { ship: self }
    )
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
