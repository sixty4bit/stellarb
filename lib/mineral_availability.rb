# frozen_string_literal: true

# Determines which minerals are available in a given star system
# based on star type and distance from The Cradle.
#
# Tier availability by distance:
# - Near Cradle (< 100 units): Tier 1-2 (common, uncommon)
# - Mid-range (100-500 units): Tier 1-3 (+ rare)
# - Deep space (> 500 units): Tier 1-4 (+ exotic)
#
# Futuristic minerals require:
# - Correct star type (mapped in Minerals constant)
# - Distance > 500 units from Cradle
#
# Reference: Source doc Section 1.2, 5.1-5.3
module MineralAvailability
  # Star type to futuristic mineral mapping
  # Based on Minerals::FUTURISTIC found_in attribute
  STAR_TYPE_MINERALS = {
    "neutron_star" => "Stellarium",
    "black_hole_proximity" => "Voidite",
    "binary_system" => "Chronite",
    "blue_giant" => "Plasmaite",
    "yellow_giant" => "Solarite",
    "red_giant" => "Cryonite" # Ice Giants mapped to red_giant for game purposes
  }.freeze

  # Pulsars are a variant of neutron stars
  PULSAR_MINERAL = "Quantium"

  # Anomaly systems (very rare) have Exotite
  ANOMALY_MINERAL = "Exotite"

  # Nebulite found in nebula systems
  NEBULA_MINERAL = "Nebulite"

  # Darkstone threshold (> 5000 units from Cradle)
  DARKSTONE_DISTANCE = 5000

  class << self
    # Get all minerals available in a system
    # @param star_type [String] The star type of the system
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param z [Integer] Z coordinate
    # @return [Array<Hash>] Available minerals
    def for_system(star_type:, x:, y:, z:)
      distance = distance_from_cradle(x, y, z)
      tiers = available_tiers(distance)

      # Get real minerals by tier
      minerals = Minerals::ALL.select { |m| tiers.include?(m[:tier]) }

      # Add futuristic minerals based on star type if far enough from Cradle
      if distance > 500
        minerals += futuristic_for_star_type(star_type)
      end

      # Darkstone appears in very deep space
      if distance > DARKSTONE_DISTANCE
        darkstone = Minerals.find("Darkstone")
        minerals << darkstone if darkstone && !minerals.include?(darkstone)
      end

      minerals.uniq
    end

    # Get which tiers are available at a given distance from Cradle
    # @param distance [Float] Distance from Cradle in units
    # @return [Array<Symbol>] Available tiers
    def available_tiers(distance)
      if distance < 100
        [:common, :uncommon]
      elsif distance < 500
        [:common, :uncommon, :rare]
      else
        [:common, :uncommon, :rare, :exotic]
      end
    end

    # Calculate distance from The Cradle (0, 0, 0)
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param z [Integer] Z coordinate
    # @return [Float] Distance in units
    def distance_from_cradle(x, y, z)
      Math.sqrt(x**2 + y**2 + z**2)
    end

    # Get futuristic minerals available for a star type
    # @param star_type [String] The star type
    # @return [Array<Hash>] Futuristic minerals for this star type
    def futuristic_for_star_type(star_type)
      minerals = []

      # Check star type mapping
      if STAR_TYPE_MINERALS.key?(star_type)
        mineral = Minerals.find(STAR_TYPE_MINERALS[star_type])
        minerals << mineral if mineral
      end

      # Pulsars (variant of neutron_star) have Quantium
      if star_type == "pulsar"
        mineral = Minerals.find(PULSAR_MINERAL)
        minerals << mineral if mineral
      end

      # Nebulae have Nebulite
      if star_type == "nebula"
        mineral = Minerals.find(NEBULA_MINERAL)
        minerals << mineral if mineral
      end

      # Anomalies have Exotite
      if star_type == "anomaly"
        mineral = Minerals.find(ANOMALY_MINERAL)
        minerals << mineral if mineral
      end

      minerals
    end
  end
end
