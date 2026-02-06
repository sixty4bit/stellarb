# frozen_string_literal: true

# Tracks price deviations from procedurally generated base prices.
#
# The Static + Dynamic pricing model:
# - Base Price: Calculated mathematically from system seed (no DB lookup)
# - Price Delta: The only data stored in DB, tracks inventory shifts
#
# Current price = base_price + delta_cents
class PriceDelta < ApplicationRecord
  # Explicit table name needed because Rails inflects "PriceDelta" -> "price_delta"
  self.table_name = "price_deltas"

  # Associations
  belongs_to :system

  # Validations
  validates :commodity, presence: true
  validates :delta_cents, presence: true, numericality: { only_integer: true }
  validates :commodity, uniqueness: { scope: :system_id }

  # ===========================================
  # Price Calculations
  # ===========================================

  # Calculate the current price (base + delta)
  # @return [Integer] Current price in cents, minimum 1
  def current_price
    base = base_price
    return nil unless base

    [base + delta_cents, 1].max
  end

  # Get the base price for this commodity in this system
  # @return [Integer, nil] Base price in cents, or nil if commodity unknown
  def base_price
    base_prices = system.properties&.dig("base_prices") || {}
    base_prices[commodity] || base_prices[commodity.to_s]
  end

  # ===========================================
  # Class Methods for Price Management
  # ===========================================

  class << self
    # Apply a delta to a commodity's price in a system
    # Creates the record if it doesn't exist, otherwise updates it
    #
    # @param system [System] The system to update
    # @param commodity [String] The commodity name
    # @param change [Integer] The delta change (positive or negative)
    # @return [PriceDelta] The created or updated record
    def apply_delta(system, commodity, change)
      delta = find_or_initialize_by(system: system, commodity: commodity.to_s)
      delta.delta_cents = (delta.delta_cents || 0) + change
      delta.save!
      delta
    end

    # Get current price for a commodity in a system
    # Returns base price if no delta exists
    # Falls back to Minerals module base_price if system has no custom price
    #
    # @param system [System] The system
    # @param commodity [String] The commodity name
    # @return [Integer, nil] Current price in cents, or nil if commodity unknown
    def current_price_for(system, commodity)
      delta = find_by(system: system, commodity: commodity.to_s)

      if delta
        delta.current_price
      else
        base_prices = system.properties&.dig("base_prices") || {}
        price = base_prices[commodity.to_s] || base_prices[commodity.to_sym]
        
        # Fall back to Minerals module base price
        price ||= Minerals.find(commodity)&.fetch(:base_price, nil)
        price
      end
    end

    # Get all current prices for a system
    # Merges base prices with any deltas
    #
    # @param system [System] The system
    # @return [Hash] Commodity => current price
    def all_current_prices(system)
      base_prices = system.properties&.dig("base_prices") || {}
      deltas = where(system: system).index_by(&:commodity)

      result = base_prices.transform_keys(&:to_s).dup
      deltas.each do |commodity, delta|
        if result.key?(commodity)
          result[commodity] = [result[commodity] + delta.delta_cents, 1].max
        end
      end
      result
    end

    # Calculate price trend for a commodity in a system
    # Returns :up, :down, or :stable based on delta magnitude
    #
    # @param system [System] The system
    # @param commodity [String] The commodity name
    # @return [Symbol] :up, :down, or :stable
    def trend_for(system, commodity)
      delta = find_by(system: system, commodity: commodity.to_s)
      return :stable unless delta

      if delta.delta_cents > 10
        :up
      elsif delta.delta_cents < -10
        :down
      else
        :stable
      end
    end

    # Simulate a buy transaction (increases price due to demand)
    # @param system [System] The system
    # @param commodity [String] The commodity
    # @param quantity [Integer] Amount purchased
    # @param demand_factor [Float] Price increase per unit (default 0.5%)
    def simulate_buy(system, commodity, quantity, demand_factor: 0.005)
      current = current_price_for(system, commodity)
      current ||= Minerals.find(commodity)&.fetch(:base_price, nil)
      return nil unless current

      # Price increases based on quantity and demand factor
      increase = (current * demand_factor * quantity).round
      apply_delta(system, commodity, increase)
    end

    # Simulate a sell transaction (decreases price due to supply)
    # @param system [System] The system
    # @param commodity [String] The commodity
    # @param quantity [Integer] Amount sold
    # @param supply_factor [Float] Price decrease per unit (default 0.5%)
    def simulate_sell(system, commodity, quantity, supply_factor: 0.005)
      current = current_price_for(system, commodity)
      current ||= Minerals.find(commodity)&.fetch(:base_price, nil)
      return nil unless current

      # Price decreases based on quantity and supply factor
      decrease = (current * supply_factor * quantity).round
      apply_delta(system, commodity, -decrease)
    end
  end
end
