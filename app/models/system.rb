class System < ApplicationRecord
  include TripleId

  # Associations
  belongs_to :discovered_by, class_name: 'User', optional: true
  belongs_to :owner, class_name: 'User', optional: true
  has_many :buildings, dependent: :destroy
  has_many :ships, foreign_key: 'current_system_id'
  has_many :system_visits, dependent: :destroy
  has_many :visitors, through: :system_visits, source: :user
  has_many :departures, -> { where(event_type: 'departure') }, class_name: 'FlightRecord', foreign_key: 'from_system_id', dependent: :destroy
  has_many :arrivals, -> { where(event_type: 'arrival') }, class_name: 'FlightRecord', foreign_key: 'to_system_id', dependent: :destroy
  has_many :price_deltas, dependent: :destroy
  has_many :market_inventories, dependent: :destroy
  has_many :system_auctions, dependent: :destroy

  # Validations
  validates :x, presence: true, numericality: { in: 0..999_999 }
  validates :y, presence: true, numericality: { in: 0..999_999 }
  validates :z, presence: true, numericality: { in: 0..999_999 }
  validates :short_id, presence: true, uniqueness: true
  validates :name, presence: true

  # Ensure unique coordinates
  validates_uniqueness_of :x, scope: [:y, :z]

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :set_name, on: :create
  before_validation :set_properties, on: :create

  # ===========================================
  # System Discovery Logic
  # ===========================================

  # Generate a deterministic hash from coordinates
  # @param x [Integer] X coordinate
  # @param y [Integer] Y coordinate
  # @param z [Integer] Z coordinate
  # @return [String] SHA256 hex string
  def self.coordinate_hash(x, y, z)
    Digest::SHA256.hexdigest("#{x}|#{y}|#{z}")
  end

  # Peek at a system's procedurally generated data without persisting
  # @param x [Integer] X coordinate
  # @param y [Integer] Y coordinate
  # @param z [Integer] Z coordinate
  # @return [Hash] System data
  def self.peek(x:, y:, z:)
    ProceduralGeneration.generate_system(x, y, z)
  end

  # Discover (create) or retrieve a system at coordinates
  # Only persists on first discovery - subsequent calls return existing record
  # @param x [Integer] X coordinate
  # @param y [Integer] Y coordinate
  # @param z [Integer] Z coordinate
  # @param user [User] The user discovering/visiting the system
  # @return [System] The system record
  def self.discover_at(x:, y:, z:, user:)
    existing = find_by(x: x, y: y, z: z)
    return existing if existing

    # Get procedurally generated data
    peeked = peek(x: x, y: y, z: z)

    create!(
      x: x,
      y: y,
      z: z,
      name: peeked[:name],
      discovered_by: user,
      discovery_date: Time.current,
      properties: {
        star_type: peeked[:star_type],
        planet_count: peeked[:planet_count],
        hazard_level: peeked[:hazard_level],
        mineral_distribution: peeked[:mineral_distribution],
        base_prices: peeked[:base_prices]
      }.merge(peeked[:special_properties] || {})
    )
  end

  # Find The Cradle system (origin point at 0,0,0)
  # Creates it if it doesn't exist
  def self.cradle
    find_or_create_by!(x: 0, y: 0, z: 0) do |system|
      system.name = "The Cradle"
    end
  end

  # Check if this is The Cradle
  def is_cradle?
    x == 0 && y == 0 && z == 0
  end

  # ===========================================
  # System Ownership
  # ===========================================

  # Check if system is owned by any player
  def owned?
    owner_id.present?
  end

  # Check if system is owned by a specific user
  def owned_by?(user)
    owner_id == user&.id
  end

  # Record an owner visit (resets inactivity timer)
  # If an auction is active, it gets cancelled and bids refunded
  def record_owner_visit!(user)
    return unless owned_by?(user)

    transaction do
      # Cancel any active auction (owner reclaimed)
      active_auction = system_auctions.where(status: %w[pending active]).first
      active_auction&.cancel!(reason: "owner_reclaimed")

      # Reset the inactivity timer
      update!(owner_last_visit_at: Time.current)
    end
  end

  # Get the current active auction for this system
  def active_auction
    system_auctions.where(status: %w[pending active]).first
  end

  # Check if system is currently up for auction
  def under_auction?
    active_auction.present?
  end

  # ===========================================
  # Guest Book (Visitor Logging)
  # ===========================================

  # Returns all visits to this system ordered by first visit (guest book style)
  # @return [ActiveRecord::Relation<SystemVisit>]
  def guest_book
    system_visits.by_first_visit
  end

  # Returns recent visitors ordered by most recent visit
  # @param limit [Integer] Maximum number of visitors to return
  # @return [ActiveRecord::Relation<SystemVisit>]
  def recent_visitors(limit: 10)
    system_visits.by_last_visit.limit(limit)
  end

  # Calculate 3D Euclidean distance between two systems
  def self.distance_between(system_a, system_b)
    dx = system_b.x - system_a.x
    dy = system_b.y - system_a.y
    dz = system_b.z - system_a.z
    Math.sqrt(dx**2 + dy**2 + dz**2)
  end

  def distance_to(other_system)
    self.class.distance_between(self, other_system)
  end

  # Warp gate connections
  def warp_gates
    WarpGate.where(system_a_id: id).or(WarpGate.where(system_b_id: id))
  end

  def warp_connected_systems
    active_gates = warp_gates.active
    system_ids = active_gates.pluck(:system_a_id, :system_b_id).flatten.uniq - [id]
    System.where(id: system_ids)
  end

  def warp_connected_to?(other_system)
    WarpGate.connected?(self, other_system)
  end

  # Ships by intent
  def hostile_ships
    ships.hostile
  end

  def trading_ships
    ships.trading
  end

  # ===========================================
  # Pricing (Static + Dynamic Model)
  # ===========================================

  # Abundance modifiers for mineral prices
  # High abundance = lower prices (0.8), Low abundance = higher prices (1.2)
  ABUNDANCE_MODIFIERS = {
    "very_high" => 0.7,
    "high" => 0.8,
    "medium" => 1.0,
    "low" => 1.2,
    "very_low" => 1.5
  }.freeze

  # Get the abundance modifier for a commodity based on mineral distribution
  # @param commodity [String] The commodity name
  # @return [Float] Multiplier (0.7-1.5), defaults to 1.0 if unknown
  def abundance_modifier(commodity)
    distribution = mineral_distribution
    return 1.0 if distribution.blank?

    # Find the planet/node that has this commodity
    distribution.each do |_planet_idx, planet_data|
      minerals = planet_data["minerals"] || planet_data[:minerals] || []
      next unless minerals.include?(commodity.to_s)

      abundance = (planet_data["abundance"] || planet_data[:abundance]).to_s
      return ABUNDANCE_MODIFIERS[abundance] || 1.0
    end

    1.0  # Commodity not found in distribution
  end

  # Calculate the market price for a commodity applying all modifiers
  # Formula: base_price × abundance_modifier × (product of all building modifiers)
  # @param commodity [String] The commodity name
  # @return [Integer, nil] Final price rounded to integer, or nil if commodity unknown
  def calculate_market_price(commodity)
    base = base_prices[commodity.to_s] || base_prices[commodity.to_sym]
    return nil unless base

    # Apply abundance modifier
    price = base * abundance_modifier(commodity)

    # Apply all operational building modifiers (product)
    buildings.each do |building|
      next unless building.respond_to?(:operational?) && building.operational?

      modifier = building.price_modifier_for(commodity)
      price *= modifier
    end

    price.round
  end

  # Get the current price for a commodity
  # Base price (from seed) + delta (from DB)
  #
  # @param commodity [String] The commodity name
  # @return [Integer, nil] Current price in cents, or nil if unknown commodity
  def current_price(commodity)
    PriceDelta.current_price_for(self, commodity)
  end

  # Get all current prices (base + deltas merged)
  # @return [Hash] Commodity => current price
  def current_prices
    PriceDelta.all_current_prices(self)
  end

  # Get base prices (no deltas applied)
  # @return [Hash] Commodity => base price
  def base_prices
    properties&.dig("base_prices") || properties&.dig("base_market_prices") || {}
  end

  # ===========================================
  # Mineral Distribution
  # ===========================================

  # Get the raw mineral distribution for this system
  # @return [Hash] Planet index => {minerals: [], abundance: symbol}
  def mineral_distribution
    properties&.dig("mineral_distribution") || {}
  end

  # Get all unique minerals available in this system
  # @return [Array<String>] List of mineral names
  def available_minerals
    mineral_distribution.values.flat_map do |planet_data|
      planet_data["minerals"] || planet_data[:minerals] || []
    end.uniq
  end

  # Check if a specific mineral is available in this system
  # @param mineral [String] Mineral name to check
  # @return [Boolean] True if available
  def mineral_available?(mineral)
    available_minerals.include?(mineral.to_s)
  end

  # Get minerals available on a specific planet
  # @param planet_index [Integer] Zero-based planet index
  # @return [Hash, nil] Planet mineral data or nil if planet doesn't exist
  def minerals_on_planet(planet_index)
    mineral_distribution[planet_index] ||
      mineral_distribution[planet_index.to_s]
  end

  # Get all minerals of a specific tier in this system
  # @param tier [Symbol] :basic, :intermediate, :advanced, or :rare
  # @return [Array<String>] Minerals of that tier present in this system
  def minerals_by_tier(tier)
    tier_minerals = MineralDistribution.minerals_for_tier(tier)
    available_minerals & tier_minerals
  end

  # Check if this system is in the starter zone (near The Cradle)
  # @return [Boolean] True if in starter zone
  def starter_zone?
    MineralDistribution.starter_zone?(x, y, z)
  end

  private

  def generate_short_id
    return if short_id.present?

    base = "sy-#{name[0, 3].downcase}" if name.present?
    base ||= "sy-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while System.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def set_name
    return if name.present?

    if is_cradle?
      self.name = "The Cradle"
    else
      # Generate a unique system name based on coordinates
      # This is a placeholder - could be enhanced with a name generator
      self.name = "System-#{x}-#{y}-#{z}"
    end
  end

  def set_properties
    return if properties.present?

    # Generate system properties using the procedural generator
    seed = Digest::SHA256.hexdigest("#{x}|#{y}|#{z}")

    if is_cradle?
      # The Cradle has fixed tutorial properties
      self.properties = {
        star_type: 'yellow_dwarf',
        planet_count: 5,
        hazard_level: 0,
        security_level: 'high',
        is_tutorial_zone: true,
        base_prices: {
          "iron" => 10,
          "copper" => 15,
          "water" => 5,
          "food" => 20,
          "fuel" => 30,
          "luxury_goods" => 100
        }
      }
    else
      # Use procedural generation for other systems
      self.properties = ProceduralGeneration::SystemGenerator.call(
        seed: 'stellarb',
        x: x,
        y: y,
        z: z
      )
    end
  end
end
