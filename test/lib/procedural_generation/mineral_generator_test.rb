# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/mineral_generator'

class ProceduralGeneration::MineralGeneratorTest < ActiveSupport::TestCase
  test "generates valid mineral deposits" do
    deposits = ProceduralGeneration::MineralGenerator.call(
      planet_seed: "test_seed",
      planet_type: "rocky"
    )

    assert_kind_of Array, deposits
    assert deposits.length.between?(1, 10)

    deposits.each do |deposit|
      # Check structure
      assert_kind_of Hash, deposit
      assert deposit.key?(:mineral)
      assert deposit.key?(:quantity)
      assert deposit.key?(:purity)
      assert deposit.key?(:depth)

      # Check mineral is valid
      all_minerals = ProceduralGeneration::MineralGenerator::REAL_MINERALS +
                     ProceduralGeneration::MineralGenerator::EXOTIC_MINERALS
      assert_includes all_minerals, deposit[:mineral]

      # Check quantity range
      assert deposit[:quantity].between?(100, 200_000) # With multipliers

      # Check purity range
      assert deposit[:purity].between?(0.1, 1.0)

      # Check depth is valid
      assert_includes ProceduralGeneration::MineralGenerator::DEPTHS, deposit[:depth]
    end
  end

  test "generates deterministic results" do
    deposits1 = ProceduralGeneration::MineralGenerator.call(
      planet_seed: "test_seed",
      planet_type: "rocky"
    )
    deposits2 = ProceduralGeneration::MineralGenerator.call(
      planet_seed: "test_seed",
      planet_type: "rocky"
    )

    assert_equal deposits1, deposits2
  end

  test "exotic minerals are rare (~2%)" do
    # Generate many deposits to check exotic mineral rate
    total_deposits = 0
    exotic_deposits = 0

    100.times do |i|
      deposits = ProceduralGeneration::MineralGenerator.call(
        planet_seed: "seed#{i}",
        planet_type: "rocky"
      )

      deposits.each do |deposit|
        total_deposits += 1
        if ProceduralGeneration::MineralGenerator::EXOTIC_MINERALS.include?(deposit[:mineral])
          exotic_deposits += 1
        end
      end
    end

    # Should be around 2% with some tolerance
    exotic_rate = (exotic_deposits.to_f / total_deposits) * 100
    assert exotic_rate.between?(0, 5), "Exotic rate was #{exotic_rate}%, expected ~2%"
  end

  test "planet type affects quantity" do
    volcanic_deposits = ProceduralGeneration::MineralGenerator.call(
      planet_seed: "test_seed",
      planet_type: "volcanic"
    )

    gas_giant_deposits = ProceduralGeneration::MineralGenerator.call(
      planet_seed: "test_seed",
      planet_type: "gas_giant"
    )

    # Volcanic should have higher quantities on average
    volcanic_avg = volcanic_deposits.sum { |d| d[:quantity] } / volcanic_deposits.length.to_f
    gas_giant_avg = gas_giant_deposits.sum { |d| d[:quantity] } / gas_giant_deposits.length.to_f

    assert volcanic_avg > gas_giant_avg
  end
end