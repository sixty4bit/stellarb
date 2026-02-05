# frozen_string_literal: true

# Mineral distribution configuration and helpers.
#
# Minerals are organized into tiers based on rarity and utility:
# - Basic: Common, used for basic construction (iron, copper, etc.)
# - Intermediate: Processed materials (steel, alloys, etc.)
# - Advanced: High-tech construction (titanium, carbon fiber, etc.)
# - Rare: End-game and special items (uranium, plutonium, exotic matter, etc.)
#
# Planets near The Cradle (starter zone) have higher chances of basic minerals.
module MineralDistribution
  # ===========================================
  # Mineral Tiers
  # ===========================================

  BASIC_MINERALS = %w[
    iron copper aluminum silicon water ice coal
  ].freeze

  INTERMEDIATE_MINERALS = %w[
    steel bronze alloy glass ceramics hydrogen helium
  ].freeze

  ADVANCED_MINERALS = %w[
    titanium carbon_fiber superconductor platinum gold silver
  ].freeze

  RARE_MINERALS = %w[
    uranium plutonium exotic_matter dark_crystal antimatter
  ].freeze

  ALL_MINERALS = (BASIC_MINERALS + INTERMEDIATE_MINERALS + ADVANCED_MINERALS + RARE_MINERALS).freeze

  # ===========================================
  # Abundance Levels
  # ===========================================

  ABUNDANCE_LEVELS = %i[very_low low medium high very_high].freeze

  # Extraction rates per hour based on abundance (base units)
  EXTRACTION_RATES = {
    very_low: 5,
    low: 15,
    medium: 30,
    high: 50,
    very_high: 100
  }.freeze

  # ===========================================
  # Tier Queries
  # ===========================================

  class << self
    # Get the tier of a mineral
    # @param mineral [String] Mineral name
    # @return [Symbol, nil] :basic, :intermediate, :advanced, :rare, or nil
    def tier_for(mineral)
      mineral_str = mineral.to_s
      return :basic if BASIC_MINERALS.include?(mineral_str)
      return :intermediate if INTERMEDIATE_MINERALS.include?(mineral_str)
      return :advanced if ADVANCED_MINERALS.include?(mineral_str)
      return :rare if RARE_MINERALS.include?(mineral_str)
      nil
    end

    # Get all minerals for a tier
    # @param tier [Symbol] :basic, :intermediate, :advanced, or :rare
    # @return [Array<String>] Minerals in that tier
    def minerals_for_tier(tier)
      case tier
      when :basic then BASIC_MINERALS
      when :intermediate then INTERMEDIATE_MINERALS
      when :advanced then ADVANCED_MINERALS
      when :rare then RARE_MINERALS
      else []
      end
    end

    # Get extraction rate for an abundance level
    # @param abundance [Symbol, String] Abundance level
    # @return [Integer] Base extraction rate per hour
    def extraction_rate(abundance)
      EXTRACTION_RATES[abundance.to_sym] || EXTRACTION_RATES[:medium]
    end

    # Check if a system coordinate is in the "starter zone" (near The Cradle)
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param z [Integer] Z coordinate
    # @param radius [Integer] Radius of starter zone (default 100)
    # @return [Boolean] True if in starter zone
    def starter_zone?(x, y, z, radius: 100)
      distance = Math.sqrt(x**2 + y**2 + z**2)
      distance <= radius
    end

    # Weight minerals for generation based on distance from cradle
    # Closer to cradle = more basic minerals
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param z [Integer] Z coordinate
    # @return [Hash] Weights for each tier
    def tier_weights(x, y, z)
      distance = Math.sqrt(x**2 + y**2 + z**2)

      # At cradle (0,0,0): heavily weighted to basic
      # At distance 1000+: more balanced, rare minerals appear
      if distance < 100
        { basic: 70, intermediate: 25, advanced: 5, rare: 0 }
      elsif distance < 500
        { basic: 50, intermediate: 30, advanced: 15, rare: 5 }
      elsif distance < 1000
        { basic: 35, intermediate: 30, advanced: 25, rare: 10 }
      else
        { basic: 25, intermediate: 25, advanced: 30, rare: 20 }
      end
    end
  end
end
