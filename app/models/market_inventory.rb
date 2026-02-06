# frozen_string_literal: true

# Tracks actual stock levels for commodities in a system's market.
# Stock is depleted on player purchases, increased on player sales,
# and replenished over time by MarketRestockJob.
class MarketInventory < ApplicationRecord
  belongs_to :system

  validates :commodity, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_quantity, presence: true, numericality: { greater_than: 0 }
  validates :restock_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :commodity, uniqueness: { scope: :system_id }

  # ===========================================
  # Stock Management
  # ===========================================

  # Check if the requested quantity is available
  # @param amount [Integer] Amount to check
  # @return [Boolean]
  def available?(amount)
    quantity >= amount
  end

  # Decrease stock when a player purchases
  # @param amount [Integer] Amount to decrease
  # @return [Boolean] True if successful, false if insufficient stock
  def decrease_stock!(amount)
    return false unless available?(amount)

    decrement!(:quantity, amount)
    true
  end

  # Increase stock when a player sells (capped at max_quantity)
  # @param amount [Integer] Amount to increase
  # @return [Integer] Actual amount added (may be less if at max)
  def increase_stock!(amount)
    space_available = max_quantity - quantity
    actual_increase = [amount, space_available].min
    increment!(:quantity, actual_increase)
    actual_increase
  end

  # Replenish stock based on restock_rate (called by MarketRestockJob)
  # @return [Integer] Amount replenished
  def restock!
    increase_stock!(restock_rate)
  end

  # ===========================================
  # Procedural Generation
  # ===========================================

  # Generate initial inventory for a system based on its properties
  # @param system [System] The system to generate inventory for
  # @return [Array<MarketInventory>] Created inventory records
  def self.generate_for_system(system)
    base_prices = system.base_prices
    return [] if base_prices.blank?

    # Use system seed for deterministic generation
    seed = Digest::SHA256.hexdigest("#{system.id}|inventory")
    rng = Random.new(seed[0, 8].to_i(16))

    base_prices.keys.map do |commodity|
      # Determine max_quantity based on system properties
      # Higher hazard = less stock, near Cradle = more stock
      hazard_level = system.properties&.dig("hazard_level") || 0
      distance_factor = Math.sqrt(system.x**2 + system.y**2 + system.z**2)

      # Base max between 200-1000, modified by hazard and distance
      base_max = 200 + rng.rand(800)
      hazard_penalty = hazard_level * 50
      distance_penalty = [distance_factor / 100, 200].min

      max_qty = [(base_max - hazard_penalty - distance_penalty).to_i, 50].max

      # Start with 50-100% of max stock
      starting_qty = (max_qty * (0.5 + rng.rand * 0.5)).to_i

      # Restock rate: 5-25 units per hour based on commodity
      restock = 5 + rng.rand(20)

      find_or_create_by!(system: system, commodity: commodity) do |inv|
        inv.quantity = starting_qty
        inv.max_quantity = max_qty
        inv.restock_rate = restock
      end
    end
  end

  # ===========================================
  # Querying
  # ===========================================

  # Get inventory for a commodity in a system, creating if needed
  # @param system [System]
  # @param commodity [String]
  # @return [MarketInventory]
  def self.for_system_commodity(system, commodity)
    find_by(system: system, commodity: commodity) ||
      generate_for_system(system).find { |inv| inv.commodity == commodity.to_s }
  end
end
