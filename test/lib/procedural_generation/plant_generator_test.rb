# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/plant_generator'

class ProceduralGeneration::PlantGeneratorTest < ActiveSupport::TestCase
  test "generates valid plant arrays" do
    plants = ProceduralGeneration::PlantGenerator.call(
      planet_seed: "test_seed",
      planet_type: "jungle"
    )

    assert_kind_of Array, plants
    assert plants.length.between?(0, 5)

    plants.each do |plant|
      assert_kind_of String, plant
      assert_includes ProceduralGeneration::PlantGenerator::PLANT_TYPES[:jungle], plant
    end
  end

  test "generates deterministic results" do
    plants1 = ProceduralGeneration::PlantGenerator.call(
      planet_seed: "test_seed",
      planet_type: "oceanic"
    )
    plants2 = ProceduralGeneration::PlantGenerator.call(
      planet_seed: "test_seed",
      planet_type: "oceanic"
    )

    assert_equal plants1, plants2
  end

  test "gas giants have no plants" do
    plants = ProceduralGeneration::PlantGenerator.call(
      planet_seed: "test_seed",
      planet_type: "gas_giant"
    )

    assert_equal [], plants
  end

  test "different planet types have different plant pools" do
    jungle_plants = ProceduralGeneration::PlantGenerator.call(
      planet_seed: "test_seed",
      planet_type: "jungle"
    )
    desert_plants = ProceduralGeneration::PlantGenerator.call(
      planet_seed: "different_seed",
      planet_type: "desert"
    )

    # Should use different plant pools
    jungle_plants.each do |plant|
      assert_includes ProceduralGeneration::PlantGenerator::PLANT_TYPES[:jungle], plant
    end

    desert_plants.each do |plant|
      assert_includes ProceduralGeneration::PlantGenerator::PLANT_TYPES[:desert], plant
    end
  end

  test "plants are unique within a planet" do
    # Test multiple times with different seeds
    10.times do |i|
      plants = ProceduralGeneration::PlantGenerator.call(
        planet_seed: "seed#{i}",
        planet_type: "oceanic"
      )

      # All plants should be unique
      assert_equal plants.length, plants.uniq.length
    end
  end
end