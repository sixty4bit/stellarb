# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/ship_generator'

class ProceduralGeneration::ShipGeneratorTest < ActiveSupport::TestCase
  RACES = %w[vex solari krog myrmidon].freeze
  HULL_SIZES = %i[scout frigate transport cruiser titan].freeze
  TIERS = (1..5).to_a.freeze

  test "generates 100 unique ship types (4 races x 5 hull sizes x 5 tiers)" do
    ships = ProceduralGeneration::ShipGenerator.generate_all_types

    assert_equal 100, ships.length
  end

  test "all 4 races are represented" do
    ships = ProceduralGeneration::ShipGenerator.generate_all_types

    races = ships.map { |s| s[:race] }.uniq
    assert_equal RACES.sort, races.sort
  end

  test "all 5 hull sizes are represented" do
    ships = ProceduralGeneration::ShipGenerator.generate_all_types

    hull_sizes = ships.map { |s| s[:hull_size] }.uniq
    assert_equal HULL_SIZES.sort, hull_sizes.sort
  end

  test "all 5 tiers are represented" do
    ships = ProceduralGeneration::ShipGenerator.generate_all_types

    tiers = ships.map { |s| s[:tier] }.uniq.sort
    assert_equal TIERS, tiers
  end

  test "generates deterministic results" do
    ship1 = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :scout, tier: 1)
    ship2 = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :scout, tier: 1)

    assert_equal ship1, ship2
  end

  test "attributes scale with tier (power law)" do
    tier1 = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :frigate, tier: 1)
    tier5 = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :frigate, tier: 5)

    # Higher tier ships should have better stats
    assert tier5[:cargo_capacity] > tier1[:cargo_capacity], "Tier 5 should have more cargo"
    assert tier5[:hull_points] > tier1[:hull_points], "Tier 5 should have more hull"
    assert tier5[:cost] > tier1[:cost], "Tier 5 should cost more"
  end

  test "cost scales approximately 1.8x per tier" do
    costs = TIERS.map do |tier|
      ship = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :frigate, tier: tier)
      ship[:cost]
    end

    # Check cost ratios between consecutive tiers
    ratios = []
    costs.each_cons(2) { |c1, c2| ratios << (c2.to_f / c1) }

    avg_ratio = ratios.sum / ratios.length
    assert avg_ratio.between?(1.5, 2.1), "Cost ratio was #{avg_ratio}, expected ~1.8"
  end

  test "racial bonuses are applied correctly" do
    # Vex get +20% cargo
    vex_ship = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :transport, tier: 3)
    krog_ship = ProceduralGeneration::ShipGenerator.call(race: "krog", hull_size: :transport, tier: 3)

    # Vex should have more cargo than Krog (who have no cargo bonus)
    assert vex_ship[:cargo_capacity] > krog_ship[:cargo_capacity], "Vex should have cargo bonus"

    # Krog get +20% hull
    assert krog_ship[:hull_points] > vex_ship[:hull_points], "Krog should have hull bonus"
  end

  test "ship has all required attributes" do
    ship = ProceduralGeneration::ShipGenerator.call(race: "solari", hull_size: :cruiser, tier: 4)

    required_attributes = %i[
      race hull_size tier name cargo_capacity fuel_efficiency
      maneuverability hardpoints crew_min crew_max maintenance_rate
      hull_points sensor_range cost
    ]

    required_attributes.each do |attr|
      assert ship.key?(attr), "Ship missing #{attr}"
    end
  end

  test "myrmidon ships cost 20% less" do
    vex_ship = ProceduralGeneration::ShipGenerator.call(race: "vex", hull_size: :frigate, tier: 3)
    myrmidon_ship = ProceduralGeneration::ShipGenerator.call(race: "myrmidon", hull_size: :frigate, tier: 3)

    # Myrmidon should cost roughly 80% of Vex (20% discount)
    expected_ratio = 0.8
    actual_ratio = myrmidon_ship[:cost].to_f / vex_ship[:cost]

    assert actual_ratio.between?(0.7, 0.9), "Myrmidon cost ratio was #{actual_ratio}, expected ~0.8"
  end

  test "solari ships have better sensors" do
    solari_ship = ProceduralGeneration::ShipGenerator.call(race: "solari", hull_size: :scout, tier: 3)
    krog_ship = ProceduralGeneration::ShipGenerator.call(race: "krog", hull_size: :scout, tier: 3)

    assert solari_ship[:sensor_range] > krog_ship[:sensor_range], "Solari should have sensor bonus"
  end
end
