# frozen_string_literal: true

# Handles mining operations and triggers futuristic mineral discovery.
#
# When a player mines in a system with the correct star type and is
# far enough from The Cradle, they discover the associated futuristic
# mineral. Once discovered, that mineral becomes visible in all systems
# where it naturally occurs.
#
# Reference: Source doc Section 1.2
#
# @example Trigger mining and discovery
#   result = MiningService.call(user: user, system: system)
#   if result.success?
#     result.discoveries.each { |mineral| puts "Discovered: #{mineral}!" }
#   end
#
class MiningService
  Result = Struct.new(:success?, :discoveries, :error, keyword_init: true)

  # Star type to futuristic mineral mapping (same as MineralAvailability)
  STAR_TYPE_MINERALS = {
    "neutron_star" => "Stellarium",
    "black_hole_proximity" => "Voidite",
    "binary_system" => "Chronite",
    "blue_giant" => "Plasmaite",
    "yellow_giant" => "Solarite",
    "red_giant" => "Cryonite"
  }.freeze

  # Distance threshold for futuristic mineral discovery
  FUTURISTIC_DISTANCE = 500

  # Distance threshold for Darkstone discovery
  DARKSTONE_DISTANCE = 5000

  def self.call(user:, system:)
    new(user: user, system: system).call
  end

  def initialize(user:, system:)
    @user = user
    @system = system
    @discoveries = []
  end

  def call
    ActiveRecord::Base.transaction do
      check_for_discoveries
    end

    Result.new(success?: true, discoveries: @discoveries)
  rescue StandardError => e
    Result.new(success?: false, discoveries: [], error: e.message)
  end

  private

  attr_reader :user, :system

  def check_for_discoveries
    distance = distance_from_cradle

    # Check star type-based futuristic minerals (require distance > 500)
    if distance > FUTURISTIC_DISTANCE
      star_type = system.properties&.dig("star_type")
      if star_type && STAR_TYPE_MINERALS.key?(star_type)
        mineral_name = STAR_TYPE_MINERALS[star_type]
        try_discover(mineral_name)
      end
    end

    # Check for Darkstone (very deep space)
    if distance > DARKSTONE_DISTANCE
      try_discover("Darkstone")
    end
  end

  def try_discover(mineral_name)
    return if user.mineral_discovered?(mineral_name)

    discovery = user.mineral_discoveries.create!(
      mineral_name: mineral_name,
      discovered_in_system: system
    )

    @discoveries << mineral_name if discovery.persisted?
  end

  def distance_from_cradle
    Math.sqrt(system.x**2 + system.y**2 + system.z**2)
  end
end
