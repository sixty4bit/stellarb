class Building < ApplicationRecord
  include TripleId

  def to_param
    short_id
  end
  include Turbo::Broadcastable

  # Custom Errors
  class UpgradeError < StandardError; end

  # Associations
  belongs_to :user, optional: true
  belongs_to :system
  has_many :hirings, as: :assignable, dependent: :destroy
  has_many :staff, through: :hirings, source: :hired_recruit
  has_many :incidents, as: :asset, dependent: :destroy

  # Constants
  RACES = %w[vex solari krog myrmidon].freeze
  FUNCTIONS = %w[extraction refining logistics civic defense].freeze
  STATUSES = %w[active inactive destroyed under_construction].freeze
  MAX_TIER = 5

  # ===========================================
  # Marketplace (Civic) Configuration
  # ===========================================
  # Fee rates by tier (5% at T1, decreasing to 1% at T5)
  MARKETPLACE_FEE_RATES = {
    1 => 0.05,  # 5%
    2 => 0.04,  # 4%
    3 => 0.03,  # 3%
    4 => 0.02,  # 2%
    5 => 0.01   # 1%
  }.freeze

  # NPC volume multiplier by tier (1x at T1, up to 25x at T5)
  # This affects market inventory and restock rates
  MARKETPLACE_NPC_VOLUME = {
    1 => 1,   # 1x
    2 => 7,   # 7x
    3 => 13,  # 13x
    4 => 19,  # 19x
    5 => 25   # 25x
  }.freeze

  # ===========================================
  # Warehouse (Logistics) Capacity Configuration
  # ===========================================
  # Capacity bonus multipliers by tier (e.g., 0.5 = +50%)
  WAREHOUSE_CAPACITY_BONUS = {
    1 => 0.5,   # +50%
    2 => 1.0,   # +100%
    3 => 2.0,   # +200%
    4 => 4.0,   # +400%
    5 => 8.0    # +800%
  }.freeze

  # Maximum trade size limits by tier
  WAREHOUSE_MAX_TRADE_SIZE = {
    1 => 500,
    2 => 1_000,
    3 => 2_500,
    4 => 5_000,
    5 => 10_000
  }.freeze

  # Restock rate multipliers by tier
  WAREHOUSE_RESTOCK_MULTIPLIER = {
    1 => 1.25,  # +25%
    2 => 1.5,   # +50%
    3 => 2.0,   # +100%
    4 => 3.0,   # +200%
    5 => 5.0    # +400%
  }.freeze

  # ===========================================
  # Building Costs Configuration
  # ===========================================
  # Base credits cost for each function type by tier
  # Costs from source doc Section 3.3-3.6
  # Mine (extraction): 10k-250k
  # Warehouse (logistics): 5k-300k
  # Marketplace (civic): 8k-300k
  # Factory (refining): 25k-1M
  BUILDING_COSTS = {
    "extraction" => { 1 => 10_000, 2 => 25_000, 3 => 50_000, 4 => 100_000, 5 => 250_000 },
    "refining" => { 1 => 25_000, 2 => 60_000, 3 => 150_000, 4 => 400_000, 5 => 1_000_000 },
    "logistics" => { 1 => 5_000, 2 => 15_000, 3 => 40_000, 4 => 100_000, 5 => 300_000 },
    "civic" => { 1 => 8_000, 2 => 20_000, 3 => 50_000, 4 => 120_000, 5 => 300_000 },
    "defense" => { 1 => 15_000, 2 => 40_000, 3 => 100_000, 4 => 250_000, 5 => 600_000 }
  }.freeze

  # Racial cost modifiers (percentage adjustment)
  RACIAL_COST_MODIFIERS = {
    "vex" => 1.0,        # Standard pricing
    "solari" => 1.1,     # Premium for advanced tech
    "krog" => 1.15,      # Premium for fortified construction
    "myrmidon" => 0.9    # Discount due to efficient construction
  }.freeze

  # Function display names
  FUNCTION_NAMES = {
    "extraction" => "Extraction Facility",
    "refining" => "Refinery",
    "logistics" => "Logistics Hub",
    "civic" => "Civic Center",
    "defense" => "Defense Platform"
  }.freeze

  # ===========================================
  # Factory (Refining) Specialization Configuration
  # ===========================================
  # 8 factory specializations with their input minerals and output components
  # Factories INCREASE input prices (demand) and DECREASE output prices (supply)
  FACTORY_SPECIALIZATIONS = {
    "basic" => {
      inputs: %w[iron copper aluminum coal],
      outputs: %w[basic_components hull_plating]
    },
    "electronics" => {
      inputs: %w[silicon copper gold silver],
      outputs: %w[electronics_components circuit_boards sensors]
    },
    "structural" => {
      inputs: %w[iron titanium carbon steel],
      outputs: %w[structural_components reinforced_plating frameworks]
    },
    "power" => {
      inputs: %w[uranium thorium lithium cobalt],
      outputs: %w[power_cells reactor_cores capacitors]
    },
    "propulsion" => {
      inputs: %w[tungsten titanium helium hydrogen],
      outputs: %w[engine_components thrusters fuel_injectors]
    },
    "weapons" => {
      inputs: %w[tungsten chromium platinum neodymium],
      outputs: %w[weapon_components targeting_systems ammunition]
    },
    "defense" => {
      inputs: %w[titanium lead iridium osmium],
      outputs: %w[shield_generators armor_plating defense_modules]
    },
    "advanced" => {
      inputs: %w[platinum palladium quantium stellarium],
      outputs: %w[advanced_components quantum_processors ftl_cores]
    }
  }.freeze

  # Factory input price increase per tier (+10% base, +5% per additional tier)
  # T1=+10%, T2=+15%, T3=+20%, T4=+25%, T5=+30%
  FACTORY_INPUT_PRICE_INCREASE_BASE = 0.10
  FACTORY_INPUT_PRICE_INCREASE_PER_TIER = 0.05

  # Factory output price decrease per tier (-5% per tier)
  # T1=-5%, T2=-10%, T3=-15%, T4=-20%, T5=-25%
  FACTORY_OUTPUT_PRICE_DECREASE_PER_TIER = 0.05

  # ===========================================
  # Building Cost Calculations
  # ===========================================

  # Calculate the cost for a building with given function, tier, and race
  # @param function [String] One of FUNCTIONS
  # @param tier [Integer] 1-5
  # @param race [String] One of RACES
  # @return [Integer] Total credits cost
  def self.cost_for(function:, tier:, race:)
    validate_building_params!(function: function, tier: tier, race: race)

    base_cost = BUILDING_COSTS[function][tier]
    modifier = RACIAL_COST_MODIFIERS[race]
    (base_cost * modifier).round
  end

  # Return all constructable building configurations
  # @return [Array<Hash>] Array of building type configurations
  def self.constructable_types
    types = []
    FUNCTIONS.each do |function|
      RACES.each do |race|
        (1..5).each do |tier|
          types << {
            function: function,
            race: race,
            tier: tier,
            cost: cost_for(function: function, tier: tier, race: race),
            name: "#{race.capitalize} #{FUNCTION_NAMES[function]} (Tier #{tier})"
          }
        end
      end
    end
    types
  end

  # ===========================================
  # Tier Table Data for Display
  # ===========================================

  # Get tier table data for a specific building type
  # @param function [String] Building function (extraction, logistics, civic, refining)
  # @return [Hash] Table data with name, tiers array containing costs and effects
  def self.tier_table_for(function)
    validate_function!(function)

    {
      name: FUNCTION_NAMES[function],
      tiers: (1..5).map { |tier| tier_data_for(function, tier) }
    }
  end

  # Get all tier tables for all building types
  # @return [Hash] Hash of function => tier table data
  def self.all_tier_tables
    %w[extraction logistics civic refining].each_with_object({}) do |function, tables|
      tables[function] = tier_table_for(function)
    end
  end

  # Build tier data for a specific function and tier
  # @param function [String] Building function
  # @param tier [Integer] Tier level 1-5
  # @return [Hash] Tier data with cost and effects
  def self.tier_data_for(function, tier)
    {
      tier: tier,
      cost: BUILDING_COSTS[function][tier],
      effects: effects_for(function, tier)
    }
  end

  # Get effects hash for a specific function and tier
  # @param function [String] Building function
  # @param tier [Integer] Tier level 1-5
  # @return [Hash] Effects specific to building type
  def self.effects_for(function, tier)
    case function
    when "extraction"
      {
        supply_bonus: "+#{MINE_SUPPLY_BONUS[tier]}%",
        price_effect: "-#{(tier * MINE_PRICE_REDUCTION_PER_TIER * 100).to_i}%"
      }
    when "logistics"
      {
        capacity_bonus: "+#{(WAREHOUSE_CAPACITY_BONUS[tier] * 100).to_i}%",
        max_trade_size: WAREHOUSE_MAX_TRADE_SIZE[tier]
      }
    when "civic"
      {
        fee: "#{(MARKETPLACE_FEE_RATES[tier] * 100).to_i}%",
        npc_volume: "#{MARKETPLACE_NPC_VOLUME[tier]}x"
      }
    when "refining"
      input_increase = (FACTORY_INPUT_PRICE_INCREASE_BASE + ((tier - 1) * FACTORY_INPUT_PRICE_INCREASE_PER_TIER)) * 100
      output_decrease = tier * FACTORY_OUTPUT_PRICE_DECREASE_PER_TIER * 100
      {
        input_demand: "+#{input_increase.to_i}%",
        output_supply: "-#{output_decrease.to_i}%"
      }
    else
      {}
    end
  end

  private_class_method def self.validate_function!(function)
    unless FUNCTIONS.include?(function)
      raise ArgumentError, "Invalid function: #{function}. Must be one of: #{FUNCTIONS.join(', ')}"
    end
  end

  private_class_method def self.validate_building_params!(function:, tier:, race:)
    unless FUNCTIONS.include?(function)
      raise ArgumentError, "Invalid function: #{function}. Must be one of: #{FUNCTIONS.join(', ')}"
    end
    unless (1..5).include?(tier)
      raise ArgumentError, "Invalid tier: #{tier}. Must be 1-5"
    end
    unless RACES.include?(race)
      raise ArgumentError, "Invalid race: #{race}. Must be one of: #{RACES.join(', ')}"
    end
  end

  # Validations
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :race, presence: true, inclusion: { in: RACES }
  validates :function, presence: true, inclusion: { in: FUNCTIONS }
  validates :tier, presence: true, numericality: { in: 1..5 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Building type-specific validations
  validate :mine_specialization_required, if: :extraction?
  validate :mine_specialization_matches_system_minerals, if: :extraction?
  validate :one_mine_per_mineral_per_system, if: :extraction?
  validate :one_warehouse_per_system, if: :logistics?
  validate :one_marketplace_per_system, if: :civic?
  validate :factory_requires_marketplace, if: :refining?
  validate :factory_specialization_required, if: :refining?
  validate :factory_specialization_valid, if: :refining?
  validate :unique_factory_specialization, if: :refining?

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :generate_building_attributes, on: :create

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_function, ->(function) { where(function: function) }
  scope :disabled, -> { where.not(disabled_at: nil) }
  scope :operational, -> { where(disabled_at: nil).where.not(status: 'destroyed') }
  scope :under_construction, -> { where(status: 'under_construction') }
  scope :construction_complete, -> { under_construction.where("construction_ends_at <= ?", Time.current) }

  # Disabled state (pip infestation)
  def disabled?
    disabled_at.present?
  end

  def operational?
    !disabled? && status == 'active'
  end

  # ===========================================
  # Mine Configuration (Section 3.3)
  # ===========================================
  # Supply bonus per tier (stock increase)
  MINE_SUPPLY_BONUS = {
    1 => 20,   # +20%
    2 => 40,   # +40%
    3 => 60,   # +60%
    4 => 100,  # +100%
    5 => 150   # +150%
  }.freeze

  # Price reduction per tier (-5% per tier)
  # T1=-5%, T2=-10%, T3=-15%, T4=-20%, T5=-25%
  MINE_PRICE_REDUCTION_PER_TIER = 0.05

  # Returns the price modifier this building applies to a commodity
  # Mines reduce the price of their target mineral by 5% per tier
  # Factories increase input prices by 10-30% and decrease output prices by 5-25%
  # @param commodity [String, nil] The commodity to check
  # @return [Float] Multiplier for commodity prices (1.0 = no effect)
  def price_modifier_for(commodity)
    return 1.0 unless operational?

    commodity_lower = commodity.to_s.downcase

    # Mine price reduction (extraction buildings)
    if extraction?
      return 1.0 unless commodity_lower == specialization.to_s.downcase
      # -5% per tier: T1=0.95, T2=0.90, T3=0.85, T4=0.80, T5=0.75
      return 1.0 - (tier * MINE_PRICE_REDUCTION_PER_TIER)
    end

    # Factory pricing (refining buildings)
    if refining?
      # Check if commodity is a factory input (price increase)
      inputs_lower = factory_inputs.map(&:downcase)
      if inputs_lower.include?(commodity_lower)
        return input_price_modifier_for(commodity)
      end

      # Check if commodity is a factory output (price decrease)
      outputs_lower = factory_outputs.map(&:downcase)
      if outputs_lower.include?(commodity_lower)
        return output_price_modifier_for(commodity)
      end
    end

    1.0
  end

  # ===========================================
  # Factory (Refining) Pricing Methods
  # ===========================================

  # Check if this building is a factory (refining function)
  # @return [Boolean]
  def factory?
    function == "refining"
  end

  # Get the input commodities for this factory's specialization
  # @return [Array<String>] Input commodity names, or empty array if not a factory
  def factory_inputs
    return [] unless factory? && specialization.present?

    FACTORY_SPECIALIZATIONS.dig(specialization, :inputs) || []
  end

  # Get the output commodities for this factory's specialization
  # @return [Array<String>] Output commodity names, or empty array if not a factory
  def factory_outputs
    return [] unless factory? && specialization.present?

    FACTORY_SPECIALIZATIONS.dig(specialization, :outputs) || []
  end

  # Calculate the input price modifier for a factory
  # Factories INCREASE input mineral prices (demand drives prices up)
  # T1=+10%, T2=+15%, T3=+20%, T4=+25%, T5=+30%
  # @param commodity [String] The input commodity
  # @return [Float] Multiplier (1.10 to 1.30)
  def input_price_modifier_for(commodity)
    return 1.0 unless factory? && operational?
    return 1.0 unless factory_inputs.include?(commodity.to_s)

    # +10% base + 5% per tier above 1: T1=1.10, T2=1.15, T3=1.20, T4=1.25, T5=1.30
    (1.0 + FACTORY_INPUT_PRICE_INCREASE_BASE + ((tier - 1) * FACTORY_INPUT_PRICE_INCREASE_PER_TIER)).round(2)
  end

  # Calculate the output price modifier for a factory
  # Factories DECREASE output component prices (supply drives prices down)
  # T1=-5%, T2=-10%, T3=-15%, T4=-20%, T5=-25%
  # @param commodity [String] The output commodity
  # @return [Float] Multiplier (0.75 to 0.95)
  def output_price_modifier_for(commodity)
    return 1.0 unless factory? && operational?
    return 1.0 unless factory_outputs.include?(commodity.to_s)

    # -5% per tier: T1=0.95, T2=0.90, T3=0.85, T4=0.80, T5=0.75
    (1.0 - (tier * FACTORY_OUTPUT_PRICE_DECREASE_PER_TIER)).round(2)
  end

  # Check if construction is complete and transition to active
  # Called by before_action in BuildingsController
  def check_construction_complete!
    return unless status == "under_construction" && construction_ends_at.present?
    return if construction_ends_at > Time.current

    self.status = "active"
    self.construction_ends_at = nil
    save!

    # Broadcast completion to user's buildings stream
    broadcast_construction_complete
  end

  # Returns the Turbo Stream target for this user's buildings stream
  def broadcast_construction_complete_target
    "buildings_user_#{user_id}"
  end

  # Broadcasts building construction complete to user's buildings stream via Turbo Streams
  # Gracefully handles missing ActionCable in test environment
  def broadcast_construction_complete
    return unless defined?(ActionCable)

    broadcast_replace_later_to(
      broadcast_construction_complete_target,
      target: ActionView::RecordIdentifier.dom_id(self),
      partial: "buildings/building",
      locals: { building: self }
    )
  end

  # ===========================================
  # Building Upgrades
  # ===========================================

  # Check if building can be upgraded
  # @return [Boolean]
  def upgradeable?
    tier < MAX_TIER && !disabled? && status == 'active'
  end

  # Calculate the cost to upgrade to next tier
  # @return [Integer, nil] Upgrade cost, or nil if at max tier
  def upgrade_cost
    return nil if tier >= MAX_TIER

    current_cost = Building.cost_for(function: function, tier: tier, race: race)
    next_cost = Building.cost_for(function: function, tier: tier + 1, race: race)
    next_cost - current_cost
  end

  # Upgrade building to next tier
  # @param user [User] The user paying for the upgrade
  # @raise [UpgradeError] If building cannot be upgraded
  # @raise [User::InsufficientCreditsError] If user cannot afford upgrade
  def upgrade!(user:)
    raise UpgradeError, "Building is at max tier" if tier >= MAX_TIER
    raise UpgradeError, "Cannot upgrade: building is not operational" unless upgradeable?

    cost = upgrade_cost

    ActiveRecord::Base.transaction do
      user.deduct_credits!(cost)
      self.tier += 1
      regenerate_building_attributes!
      save!
    end
  end

  # ===========================================
  # Warehouse (Logistics) Capacity Methods
  # ===========================================

  # Check if this building is a warehouse (logistics function)
  # @return [Boolean]
  def warehouse?
    function == "logistics"
  end

  # Check if this building is a marketplace (civic function)
  # @return [Boolean]
  def marketplace?
    function == "civic"
  end

  # ===========================================
  # Marketplace (Civic) Methods
  # ===========================================

  # Get the fee rate for this marketplace
  # Returns nil for non-marketplace buildings
  # @return [Float, nil] Fee rate (0.05 = 5%), or nil if not a marketplace
  def marketplace_fee_rate
    return nil unless marketplace? && operational?

    MARKETPLACE_FEE_RATES[tier]
  end

  # Calculate the fee amount for a transaction
  # @param amount [Integer] Transaction amount in credits
  # @return [Integer] Fee amount in credits
  def calculate_fee(amount)
    rate = marketplace_fee_rate
    return 0 unless rate

    (amount * rate).round
  end

  # Get the NPC volume multiplier for this marketplace
  # Affects market inventory quantity and restock rates
  # Returns nil for non-marketplace buildings
  # @return [Integer, nil] Volume multiplier, or nil if not a marketplace
  def npc_volume_multiplier
    return nil unless marketplace? && operational?

    MARKETPLACE_NPC_VOLUME[tier]
  end

  # Get the capacity bonus multiplier for this warehouse
  # Increases market max_quantity by this percentage
  # @return [Float] Bonus multiplier (0.5 = +50%), or 0 if not a warehouse/disabled
  def warehouse_capacity_bonus
    return 0 unless warehouse? && operational?

    WAREHOUSE_CAPACITY_BONUS[tier] || 0
  end

  # Get the maximum trade size allowed by this warehouse
  # @return [Integer, nil] Max units per trade, or nil if not a warehouse/disabled
  def warehouse_max_trade_size
    return nil unless warehouse? && operational?

    WAREHOUSE_MAX_TRADE_SIZE[tier]
  end

  # Get the restock rate multiplier for this warehouse
  # Multiplies the base restock rate for market inventory
  # @return [Float] Multiplier (1.0 = no change), always 1.0 if not a warehouse/disabled
  def warehouse_restock_multiplier
    return 1.0 unless warehouse? && operational?

    WAREHOUSE_RESTOCK_MULTIPLIER[tier] || 1.0
  end

  # Recalculate building attributes based on current tier
  # Used after upgrades to update stats
  def regenerate_building_attributes!
    base_stats = {
      "staff_slots" => { "min" => 2, "max" => 5 },
      "maintenance_rate" => 20 * tier,
      "hardpoints" => tier,
      "storage_capacity" => 1000 * tier,
      "output_rate" => (10 * (tier ** 1.5)).to_i,
      "power_consumption" => 5 * tier,
      "durability" => 500 * tier
    }

    # Apply function-specific modifications
    case function
    when 'extraction'
      base_stats["output_rate"] = (base_stats["output_rate"] * 2).to_i
    when 'defense'
      base_stats["hardpoints"] = (base_stats["hardpoints"] * 2).to_i
      base_stats["durability"] = (base_stats["durability"] * 1.5).to_i
    when 'logistics'
      base_stats["storage_capacity"] = (base_stats["storage_capacity"] * 3).to_i
    end

    # Apply racial bonuses
    case race
    when 'vex'
      base_stats["output_rate"] = (base_stats["output_rate"] * 1.1).to_i if function == 'civic'
    when 'solari'
      base_stats["power_consumption"] = (base_stats["power_consumption"] * 1.2).to_i
    when 'krog'
      base_stats["durability"] = (base_stats["durability"] * 1.2).to_i
    when 'myrmidon'
      base_stats["maintenance_rate"] = (base_stats["maintenance_rate"] * 0.8).to_i
    end

    self.building_attributes = base_stats
  end

  private

  def generate_short_id
    return if short_id.present?

    abbrev = case function
    when 'extraction' then 'ext'
    when 'refining' then 'ref'
    when 'logistics' then 'log'
    when 'civic' then 'civ'
    when 'defense' then 'def'
    else 'bld'
    end

    base = "bl-#{abbrev}#{tier}"
    candidate = base
    counter = 2

    while Building.exists?(short_id: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def generate_building_attributes
    return if building_attributes.present?

    # This is a placeholder - would use the procedural generation engine
    base_stats = {
      staff_slots: { min: 2, max: 5 },
      maintenance_rate: 20 * tier,
      hardpoints: tier,
      storage_capacity: 1000 * tier,
      output_rate: 10 * (tier ** 1.5),
      power_consumption: 5 * tier,
      durability: 500 * tier
    }

    # Apply function-specific modifications
    case function
    when 'extraction'
      base_stats[:output_rate] *= 2
    when 'defense'
      base_stats[:hardpoints] *= 2
      base_stats[:durability] *= 1.5
    when 'logistics'
      base_stats[:storage_capacity] *= 3
    end

    # Apply racial bonuses
    case race
    when 'vex'
      base_stats[:output_rate] *= 1.1 if function == 'civic'
    when 'solari'
      base_stats[:power_consumption] *= 1.2
    when 'krog'
      base_stats[:durability] *= 1.2
    when 'myrmidon'
      base_stats[:maintenance_rate] *= 0.8
    end

    self.building_attributes = base_stats
  end

  # ===========================================
  # Function Type Helpers
  # ===========================================

  def extraction?
    function == "extraction"
  end

  def refining?
    function == "refining"
  end

  def logistics?
    function == "logistics"
  end

  def civic?
    function == "civic"
  end

  # ===========================================
  # Building Validation Methods
  # ===========================================

  # Mine (extraction) validations

  def mine_specialization_required
    if specialization.blank?
      errors.add(:specialization, "is required for extraction buildings")
    end
  end

  def mine_specialization_matches_system_minerals
    return if specialization.blank? || system.blank?

    unless system.mineral_available?(specialization)
      errors.add(:specialization, "must match a mineral available in this system")
    end
  end

  def one_mine_per_mineral_per_system
    return if specialization.blank? || system.blank?

    existing = system.buildings.where(function: "extraction", specialization: specialization)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:specialization, "already has a mine for this mineral in this system")
    end
  end

  # Warehouse (logistics) validations

  def one_warehouse_per_system
    return if system.blank?

    existing = system.buildings.where(function: "logistics")
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:function, "only one logistics building allowed per system")
    end
  end

  # Marketplace (civic) validations

  def one_marketplace_per_system
    return if system.blank?

    existing = system.buildings.where(function: "civic")
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:function, "only one civic building allowed per system")
    end
  end

  # Factory (refining) validations

  def factory_requires_marketplace
    return if system.blank?

    unless system.buildings.where(function: "civic").exists?
      errors.add(:base, "requires a marketplace (civic building) in the system")
    end
  end

  def factory_specialization_required
    if specialization.blank?
      errors.add(:specialization, "is required for refining buildings")
    end
  end

  def factory_specialization_valid
    return if specialization.blank?

    unless FACTORY_SPECIALIZATIONS.key?(specialization)
      errors.add(:specialization, "must be a valid factory specialization")
    end
  end

  def unique_factory_specialization
    return if specialization.blank? || system.blank?

    existing = system.buildings.where(function: "refining", specialization: specialization)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:specialization, "already has a factory with this specialization in this system")
    end
  end
end
