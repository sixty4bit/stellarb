# frozen_string_literal: true

require 'digest'
require_relative 'seed_helpers'
require_relative 'planet_generator'

module ProceduralGeneration
  class SystemGenerator
    include SeedHelpers

    STAR_TYPES = %w[
      red_dwarf yellow_dwarf orange_dwarf white_dwarf
      blue_giant red_giant yellow_giant
      neutron_star binary_system black_hole_proximity
    ].freeze

    # Generate a star system at given coordinates
    # @param seed [String] Base seed string
    # @param x [Integer] X coordinate (0-9, must be divisible by 3)
    # @param y [Integer] Y coordinate (0-9, must be divisible by 3)
    # @param z [Integer] Z coordinate (0-9, must be divisible by 3)
    # @return [Hash] System data with star_type and planets array
    def self.call(seed:, x:, y:, z:)
      new(seed: seed, x: x, y: y, z: z).generate
    end

    def initialize(seed:, x:, y:, z:)
      validate_coordinates!(x, y, z)
      @seed = seed
      @x = x
      @y = y
      @z = z
      @system_seed = generate_system_seed
    end

    def generate
      {
        star_type: star_type,
        planets: planets
      }
    end

    private

    attr_reader :seed, :x, :y, :z, :system_seed

    def validate_coordinates!(x, y, z)
      [x, y, z].each do |coord|
        raise ArgumentError, "Coordinate must be 0-9" unless (0..9).include?(coord)
        raise ArgumentError, "Coordinate must be divisible by 3" unless coord % 3 == 0
      end
    end

    def generate_system_seed
      Digest::SHA256.hexdigest("#{seed}|#{x}|#{y}|#{z}")
    end

    def star_type
      star_type_idx = extract_from_seed(system_seed, 0, 2, STAR_TYPES.length)
      STAR_TYPES[star_type_idx]
    end

    def planets
      # Planet count: 0-12 planets
      planet_count = extract_from_seed(system_seed, 2, 1, 13)

      # Generate each planet using PlanetGenerator
      (0...planet_count).map do |planet_index|
        PlanetGenerator.call(system_seed: system_seed, planet_index: planet_index)
      end
    end
  end
end