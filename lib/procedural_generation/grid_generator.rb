# frozen_string_literal: true

require_relative 'system_generator'

module ProceduralGeneration
  class GridGenerator
    # Grid dimensions (10x10x10)
    GRID_SIZE = 10
    # Systems are placed every 3 coordinates (0, 3, 6, 9)
    SYSTEM_SPACING = 3

    # Generate the full grid of star systems
    # @param seed [String] Base seed for the grid
    # @return [Hash] Map of coordinates to system data
    def self.call(seed:)
      new(seed: seed).generate
    end

    def initialize(seed:)
      @seed = seed
    end

    def generate
      systems = {}

      # Generate systems at valid grid positions
      valid_coordinates.each do |coords|
        x, y, z = coords
        systems[coords] = SystemGenerator.call(
          seed: seed,
          x: x,
          y: y,
          z: z
        )
      end

      systems
    end

    private

    attr_reader :seed

    def valid_coordinates
      coords = []

      # Generate all valid coordinates (0, 3, 6, 9 on each axis)
      (0...GRID_SIZE).step(SYSTEM_SPACING) do |x|
        (0...GRID_SIZE).step(SYSTEM_SPACING) do |y|
          (0...GRID_SIZE).step(SYSTEM_SPACING) do |z|
            coords << [x, y, z]
          end
        end
      end

      coords
    end
  end
end