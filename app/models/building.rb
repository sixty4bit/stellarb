class Building < ApplicationRecord
  include TripleId
  include Turbo::Broadcastable

  # Custom Errors
  class UpgradeError < StandardError; end

  # Associations
  belongs_to :user
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
  # Building Costs Configuration
  # ===========================================
  # Base credits cost for each function type by tier
  # Costs scale with building complexity and capability
  BUILDING_COSTS = {
    "extraction" => { 1 => 1000, 2 => 3000, 3 => 8000, 4 => 20000, 5 => 50000 },
    "refining" => { 1 => 1500, 2 => 4500, 3 => 12000, 4 => 30000, 5 => 75000 },
    "logistics" => { 1 => 1200, 2 => 3600, 3 => 9600, 4 => 24000, 5 => 60000 },
    "civic" => { 1 => 800, 2 => 2400, 3 => 6400, 4 => 16000, 5 => 40000 },
    "defense" => { 1 => 2000, 2 => 6000, 3 => 16000, 4 => 40000, 5 => 100000 }
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
    !disabled? && status != 'destroyed'
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
end
