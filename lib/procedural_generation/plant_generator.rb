# frozen_string_literal: true

require 'digest'
require_relative 'seed_helpers'

module ProceduralGeneration
  class PlantGenerator
    include SeedHelpers

    # Plant types per biome (for flavor/future use)
    PLANT_TYPES = {
      jungle: %w[megafern vinestalker sporetree glowmoss canopygiant
                 thornvine orchidbloom rubbertree shadowleaf mudcrawler],
      oceanic: %w[kelpforest coralbloom seagrass planktonmat floatfruit
                  tidepod shellflower deepsponge biolume currentweed],
      desert: %w[cactoid sandblossom dustshrub miragepalm thornweed
                 saltbrush crystalcactus suntrapper sandcrawler drysage],
      volcanic: %w[ashbloom lavamoss sulfurweed firevine heatstem
                   magmafern cinderfruit scorchroot emberflower pyrobulb],
      ice: %w[frostlichen snowbloom icemoss crystalfern winterleaf
              glaciervine permafrost polarweed coldsnap frozenfruit],
      rocky: %w[stonelichen rockweed mineralvine cliffbloom cavemoss
                gravelfern boulderleaf canyonroot plateaugrass dustlichen],
      barren: %w[voidlichen starmoss cosmicweed solardust nullbloom
                 vacuumfern radleaf ionvine darkmatter zerogrowth],
      gas_giant: [] # No plants on gas giants
    }.freeze

    # Generate plants for a planet
    # @param planet_seed [String] The planet's seed
    # @param planet_type [String] The planet type
    # @return [Array<String>] Array of plant types
    def self.call(planet_seed:, planet_type:)
      new(planet_seed: planet_seed, planet_type: planet_type).generate
    end

    def initialize(planet_seed:, planet_type:)
      @planet_seed = planet_seed
      @planet_type = planet_type.to_sym
      @plants_seed = generate_plants_seed
    end

    def generate
      # Get available plants for this planet type
      available_plants = PLANT_TYPES[@planet_type] || []
      return [] if available_plants.empty?

      # Number of plant types (0-5)
      plant_count = extract_from_seed(plants_seed, 0, 1, 6)
      return [] if plant_count == 0

      # Select unique plants
      selected_plants = []
      used_indices = []

      plant_count.times do |i|
        # Generate a unique index for each plant
        attempt = 0
        loop do
          # Use different seed bytes for each attempt
          plant_idx = extract_from_seed(
            plants_seed,
            1 + i + attempt,
            1,
            available_plants.length
          )

          unless used_indices.include?(plant_idx)
            used_indices << plant_idx
            selected_plants << available_plants[plant_idx]
            break
          end

          attempt += 1
          # If we've tried too many times, just take what we can get
          break if attempt > 10
        end
      end

      selected_plants.uniq # Ensure uniqueness
    end

    private

    attr_reader :planet_seed, :planet_type, :plants_seed

    def generate_plants_seed
      Digest::SHA256.hexdigest("#{planet_seed}|plants")
    end
  end
end