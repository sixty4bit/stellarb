# frozen_string_literal: true

require 'digest'

module ProceduralGeneration
  # Reserved systems in the "Talos Arm" - tutorial region adjacent to The Cradle
  # These are the first systems players explore in Phase 2: Proving Ground
  class ReservedSystem
    include SeedHelpers

    # The 6 reserved systems immediately adjacent to The Cradle (0,0,0)
    # Players in Phase 2 can discover these to learn exploration and building
    TALOS_ARM = [
      { x: 1, y: 0, z: 0 },  # Talos Prime - primary tutorial target
      { x: 0, y: 1, z: 0 },  # Talos II
      { x: 0, y: 0, z: 1 },  # Talos III
      { x: 1, y: 1, z: 0 },  # Talos IV
      { x: 1, y: 0, z: 1 },  # Talos V
      { x: 0, y: 1, z: 1 }   # Talos VI
    ].freeze

    # Named systems with specific properties for tutorial
    SYSTEM_NAMES = {
      [1, 0, 0] => "Talos Prime",
      [0, 1, 0] => "Talos II",
      [0, 0, 1] => "Talos III",
      [1, 1, 0] => "Talos IV",
      [1, 0, 1] => "Talos V",
      [0, 1, 1] => "Talos VI"
    }.freeze

    # Generate a reserved system at given coordinates
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param z [Integer] Z coordinate
    # @return [Hash] System properties suitable for tutorial
    def self.generate(x, y, z)
      new(x, y, z).generate
    end

    # Check if coordinates are in the Talos Arm
    # @param x [Integer] X coordinate
    # @param y [Integer] Y coordinate
    # @param z [Integer] Z coordinate
    # @return [Boolean]
    def self.reserved?(x, y, z)
      TALOS_ARM.any? { |c| c[:x] == x && c[:y] == y && c[:z] == z }
    end

    # Get all Talos Arm systems for a proving ground player
    # @return [Array<Hash>] List of all reserved system data
    def self.all_reserved_systems
      TALOS_ARM.map { |coords| generate(coords[:x], coords[:y], coords[:z]) }
    end

    def initialize(x, y, z)
      @x = x
      @y = y
      @z = z
      @seed = Digest::SHA256.hexdigest("talos|#{x}|#{y}|#{z}")
    end

    def generate
      {
        coordinates: { x: @x, y: @y, z: @z },
        seed: @seed,
        name: system_name,
        star_type: star_type,
        planet_count: planet_count,
        hazard_level: hazard_level,
        mineral_distribution: mineral_distribution,
        base_prices: base_prices,
        is_reserved: true,
        tutorial_eligible: true,
        is_primary_tutorial: primary_tutorial?,
        special_properties: {
          talos_arm: true,
          discovery_bonus_credits: 100,
          building_tutorial_ready: true
        }
      }
    end

    private

    def system_name
      SYSTEM_NAMES[[@x, @y, @z]] || "Talos-#{@x}#{@y}#{@z}"
    end

    def primary_tutorial?
      @x == 1 && @y == 0 && @z == 0
    end

    def star_type
      # Tutorial systems are stable yellow dwarf stars
      primary_tutorial? ? "yellow_dwarf" : stable_star_types.sample(random: deterministic_random)
    end

    def stable_star_types
      %w[yellow_dwarf orange_dwarf red_dwarf]
    end

    def deterministic_random
      Random.new(extract_int(0, 4))
    end

    def planet_count
      # At least 2 planets to support building tutorials
      # Primary tutorial has exactly 3 for consistent experience
      primary_tutorial? ? 3 : 2 + extract_int(4, 2) % 3
    end

    def hazard_level
      # Tutorial systems are safe (0-10)
      # Primary tutorial is always 0
      primary_tutorial? ? 0 : extract_int(6, 2) % 11
    end

    def mineral_distribution
      # All Talos Arm systems have iron and silicon for basic construction
      base_minerals = %w[iron silicon]

      distribution = {}
      planet_count.times do |idx|
        planet_minerals = if idx == 0
          # First planet always has construction basics
          base_minerals + bonus_mineral(idx)
        else
          bonus_minerals_for_planet(idx)
        end

        distribution[idx] = {
          minerals: planet_minerals.uniq,
          abundance: idx == 0 ? :high : :medium
        }
      end

      distribution
    end

    def bonus_mineral(planet_idx)
      minerals = %w[copper aluminum titanium water]
      idx = (extract_int(8, 2) + planet_idx) % minerals.length
      [minerals[idx]]
    end

    def bonus_minerals_for_planet(planet_idx)
      all_minerals = %w[iron silicon copper aluminum titanium water ice gold]
      seed_offset = extract_int(10, 2) + planet_idx * 100
      count = 1 + seed_offset % 3

      selected = []
      count.times do |i|
        mineral_idx = (seed_offset + i * 37) % all_minerals.length
        selected << all_minerals[mineral_idx]
      end
      selected.uniq
    end

    def base_prices
      # Stable, slightly favorable prices for tutorial
      {
        iron: 12,
        silicon: 15,
        copper: 18,
        water: 6,
        food: 22,
        fuel: 28
      }
    end

    def extract_int(byte_offset, byte_length)
      slice = @seed[byte_offset * 2, byte_length * 2]
      slice.to_i(16)
    end
  end
end
