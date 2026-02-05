# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/planet_generator'

class ProceduralGeneration::PlanetGeneratorTest < ActiveSupport::TestCase
  test "generates a valid planet hash" do
    result = ProceduralGeneration::PlanetGenerator.call(
      system_seed: "test_seed",
      planet_index: 0
    )

    assert_kind_of Hash, result
    assert result[:name].is_a?(String)
    assert_includes ProceduralGeneration::PlanetGenerator::PLANET_TYPES, result[:type]
    assert_includes ProceduralGeneration::PlanetGenerator::PLANET_SIZES, result[:size]
    assert_kind_of Array, result[:minerals]
    assert_kind_of Array, result[:plants]
  end

  test "generates deterministic results" do
    result1 = ProceduralGeneration::PlanetGenerator.call(
      system_seed: "test_seed",
      planet_index: 0
    )
    result2 = ProceduralGeneration::PlanetGenerator.call(
      system_seed: "test_seed",
      planet_index: 0
    )

    assert_equal result1, result2
  end

  test "different planet indices produce different planets" do
    result1 = ProceduralGeneration::PlanetGenerator.call(
      system_seed: "test_seed",
      planet_index: 0
    )
    result2 = ProceduralGeneration::PlanetGenerator.call(
      system_seed: "test_seed",
      planet_index: 1
    )

    # They should have different names (very likely)
    refute_equal result1[:name], result2[:name]
  end

  test "generates valid planet names" do
    # Test various planet names to ensure they follow expected patterns
    10.times do |i|
      result = ProceduralGeneration::PlanetGenerator.call(
        system_seed: "seed#{i}",
        planet_index: i
      )

      # Name should not be empty
      assert result[:name].length > 0

      # Name should contain valid characters
      assert_match(/^[\w\s\-]+$/, result[:name])
    end
  end
end