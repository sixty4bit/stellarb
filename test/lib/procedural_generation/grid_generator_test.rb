# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/grid_generator'

class ProceduralGeneration::GridGeneratorTest < ActiveSupport::TestCase
  test "generates exactly 64 systems" do
    grid = ProceduralGeneration::GridGenerator.call(seed: "test")

    assert_equal 64, grid.keys.length
  end

  test "all coordinates are divisible by 3" do
    grid = ProceduralGeneration::GridGenerator.call(seed: "test")

    grid.keys.each do |coords|
      x, y, z = coords
      assert_equal 0, x % 3, "X coordinate #{x} not divisible by 3"
      assert_equal 0, y % 3, "Y coordinate #{y} not divisible by 3"
      assert_equal 0, z % 3, "Z coordinate #{z} not divisible by 3"
    end
  end

  test "all coordinates are within bounds" do
    grid = ProceduralGeneration::GridGenerator.call(seed: "test")

    grid.keys.each do |coords|
      x, y, z = coords
      assert x >= 0 && x < 10, "X coordinate #{x} out of bounds"
      assert y >= 0 && y < 10, "Y coordinate #{y} out of bounds"
      assert z >= 0 && z < 10, "Z coordinate #{z} out of bounds"
    end
  end

  test "generates valid systems at each coordinate" do
    grid = ProceduralGeneration::GridGenerator.call(seed: "test")

    grid.each do |coords, system|
      # Each system should have required fields
      assert system.key?(:star_type)
      assert system.key?(:planets)

      # Star type should be valid
      assert_includes ProceduralGeneration::SystemGenerator::STAR_TYPES, system[:star_type]

      # Planets should be valid
      assert_kind_of Array, system[:planets]
      system[:planets].each do |planet|
        assert planet.key?(:name)
        assert planet.key?(:type)
        assert planet.key?(:size)
        assert planet.key?(:minerals)
        assert planet.key?(:plants)
      end
    end
  end

  test "generates deterministic results" do
    grid1 = ProceduralGeneration::GridGenerator.call(seed: "test123")
    grid2 = ProceduralGeneration::GridGenerator.call(seed: "test123")

    assert_equal grid1, grid2
  end

  test "different seeds produce different grids" do
    grid1 = ProceduralGeneration::GridGenerator.call(seed: "seed1")
    grid2 = ProceduralGeneration::GridGenerator.call(seed: "seed2")

    # Compare a few systems - they should be different
    system1_at_origin = grid1[[0, 0, 0]]
    system2_at_origin = grid2[[0, 0, 0]]

    # Very unlikely to have same star type and planet count
    refute_equal system1_at_origin[:star_type], system2_at_origin[:star_type]
  end

  test "includes all expected coordinates" do
    grid = ProceduralGeneration::GridGenerator.call(seed: "test")

    expected_coords = []
    [0, 3, 6, 9].each do |x|
      [0, 3, 6, 9].each do |y|
        [0, 3, 6, 9].each do |z|
          expected_coords << [x, y, z]
        end
      end
    end

    assert_equal expected_coords.sort, grid.keys.sort
  end
end