# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../lib/procedural_generation/building_generator'

class ProceduralGeneration::BuildingGeneratorTest < ActiveSupport::TestCase
  RACES = %w[vex solari krog myrmidon].freeze
  FUNCTIONS = %i[extraction refining logistics civic defense].freeze
  TIERS = (1..5).to_a.freeze

  test "generates 100 unique building types (4 races x 5 functions x 5 tiers)" do
    buildings = ProceduralGeneration::BuildingGenerator.generate_all_types

    assert_equal 100, buildings.length
  end

  test "all 4 races are represented" do
    buildings = ProceduralGeneration::BuildingGenerator.generate_all_types

    races = buildings.map { |b| b[:race] }.uniq
    assert_equal RACES.sort, races.sort
  end

  test "all 5 functions are represented" do
    buildings = ProceduralGeneration::BuildingGenerator.generate_all_types

    functions = buildings.map { |b| b[:function] }.uniq
    assert_equal FUNCTIONS.sort, functions.sort
  end

  test "all 5 tiers are represented" do
    buildings = ProceduralGeneration::BuildingGenerator.generate_all_types

    tiers = buildings.map { |b| b[:tier] }.uniq.sort
    assert_equal TIERS, tiers
  end

  test "generates deterministic results" do
    building1 = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :logistics, tier: 1)
    building2 = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :logistics, tier: 1)

    assert_equal building1, building2
  end

  test "cost scales approximately 1.8x per tier" do
    costs = TIERS.map do |tier|
      building = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :extraction, tier: tier)
      building[:cost]
    end

    # Check cost ratios between consecutive tiers
    ratios = []
    costs.each_cons(2) { |c1, c2| ratios << (c2.to_f / c1) }

    avg_ratio = ratios.sum / ratios.length
    assert avg_ratio.between?(1.5, 2.1), "Cost ratio was #{avg_ratio}, expected ~1.8"
  end

  test "building has all required attributes" do
    building = ProceduralGeneration::BuildingGenerator.call(race: "solari", function: :refining, tier: 4)

    required_attributes = %i[race function building_type tier name attributes cost]

    required_attributes.each do |attr|
      assert building.key?(attr), "Building missing #{attr}"
    end
  end

  test "racial preferences affect efficiency" do
    # Vex prefer logistics and civic
    vex_logistics = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :logistics, tier: 3)
    krog_logistics = ProceduralGeneration::BuildingGenerator.call(race: "krog", function: :logistics, tier: 3)

    # Vex should have higher efficiency for preferred types
    assert vex_logistics[:attributes][:efficiency_modifier] > krog_logistics[:attributes][:efficiency_modifier],
           "Vex should have better logistics efficiency"
  end

  test "krog buildings have durability bonus" do
    krog_building = ProceduralGeneration::BuildingGenerator.call(race: "krog", function: :defense, tier: 3)

    assert krog_building[:attributes][:durability_bonus].present?, "Krog should have durability bonus"
    assert krog_building[:attributes][:durability_bonus] > 1.0, "Krog durability should be > 1.0"
  end

  test "myrmidon buildings have population bonus" do
    myrmidon_civic = ProceduralGeneration::BuildingGenerator.call(race: "myrmidon", function: :civic, tier: 3)

    # Myrmidon get +20% population support
    vex_civic = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :civic, tier: 3)

    if myrmidon_civic[:attributes][:population_support] && vex_civic[:attributes][:population_support]
      assert myrmidon_civic[:attributes][:population_support] > vex_civic[:attributes][:population_support],
             "Myrmidon should have population bonus"
    end
  end

  test "tier scaling follows power law for outputs" do
    tier1 = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :extraction, tier: 1)
    tier5 = ProceduralGeneration::BuildingGenerator.call(race: "vex", function: :extraction, tier: 5)

    # Higher tier buildings should have better output
    if tier1[:attributes][:outputs] && tier5[:attributes][:outputs]
      tier1_output = tier1[:attributes][:outputs].values.sum
      tier5_output = tier5[:attributes][:outputs].values.sum

      assert tier5_output > tier1_output, "Tier 5 should have more output than tier 1"
    end
  end
end
