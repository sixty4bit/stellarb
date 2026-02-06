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

  test "generates base_prices key for market data" do
    result = ProceduralGeneration::SystemGenerator.call(seed: "market_test", x: 0, y: 0, z: 0)

    assert result.key?(:base_prices), "Generator should produce :base_prices key"
    assert_not result.key?(:base_market_prices), "Generator should NOT produce :base_market_prices key"
    assert_kind_of Hash, result[:base_prices]
    assert result[:base_prices].any?, "base_prices should not be empty"
  end

  test "base_prices includes all 60 minerals" do
    result = ProceduralGeneration::SystemGenerator.call(seed: "minerals_test", x: 0, y: 0, z: 0)
    base_prices = result[:base_prices]

    assert_equal 60, base_prices.size, "Should have prices for all 60 minerals"

    # Spot check some minerals exist
    assert base_prices.key?("Iron"), "Should include Iron"
    assert base_prices.key?("Gold"), "Should include Gold"
    assert base_prices.key?("Stellarium"), "Should include Stellarium"
  end

  test "base_prices match Minerals base prices" do
    result = ProceduralGeneration::SystemGenerator.call(seed: "price_test", x: 0, y: 0, z: 0)
    base_prices = result[:base_prices]

    # Prices should match the Minerals constant base prices
    assert_equal 10, base_prices["Iron"]
    assert_equal 100, base_prices["Gold"]
    assert_equal 400, base_prices["Plutonium"]
    assert_equal 500, base_prices["Stellarium"]
    assert_equal 1000, base_prices["Exotite"]
  end
end