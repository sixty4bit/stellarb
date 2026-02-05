# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/system_generator'

class ProceduralGeneration::SystemGeneratorTest < ActiveSupport::TestCase
  test "generates a valid system hash" do
    result = ProceduralGeneration::SystemGenerator.call(seed: "test", x: 0, y: 0, z: 0)

    assert_kind_of Hash, result
    assert_includes ProceduralGeneration::SystemGenerator::STAR_TYPES, result[:star_type]
    assert_kind_of Array, result[:planets]
  end

  test "generates deterministic results" do
    result1 = ProceduralGeneration::SystemGenerator.call(seed: "test", x: 0, y: 0, z: 0)
    result2 = ProceduralGeneration::SystemGenerator.call(seed: "test", x: 0, y: 0, z: 0)

    assert_equal result1, result2
  end

  test "validates coordinates are divisible by 3" do
    assert_raises(ArgumentError) do
      ProceduralGeneration::SystemGenerator.call(seed: "test", x: 1, y: 0, z: 0)
    end
  end

  test "validates coordinates are in range 0-9" do
    assert_raises(ArgumentError) do
      ProceduralGeneration::SystemGenerator.call(seed: "test", x: 12, y: 0, z: 0)
    end
  end

  test "planet count is between 0 and 12" do
    # Test multiple seeds to ensure planet count is in valid range
    10.times do |i|
      result = ProceduralGeneration::SystemGenerator.call(seed: "seed#{i}", x: 0, y: 0, z: 0)
      planet_count = result[:planets].length

      assert planet_count >= 0
      assert planet_count <= 12
    end
  end

  test "different coordinates produce different systems" do
    result1 = ProceduralGeneration::SystemGenerator.call(seed: "test", x: 0, y: 0, z: 0)
    result2 = ProceduralGeneration::SystemGenerator.call(seed: "test", x: 3, y: 3, z: 3)

    # They should be different (very unlikely to be the same)
    refute_equal result1[:star_type], result2[:star_type]
  end
end